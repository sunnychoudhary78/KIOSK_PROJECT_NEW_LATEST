#include <Wire.h>
#include <ArduinoJson.h>
#include "MAX30105.h"
#include "spo2_algorithm.h"
#include <esp_task_wdt.h>
#include <esp_system.h>

// =====================================================
// SPPC ESP32 CONTROLLER
// =====================================================
//
// FUNCTIONS:
// 1. MAX30102 heart rate + SpO2
// 2. MLX90614 temperature
// 3. Relay 1 / Relay 2 control
// 4. USB JSON communication (115200 baud)
//
// RELAYS: GPIO25 -> Relay 1, GPIO26 -> Relay 2
// I2C:    GPIO21 -> SDA,     GPIO22 -> SCL
//
// This kiosk relay board energizes on HIGH. RELAY_ACTIVE_LOW
// must stay false so {"relay":1,"state":"on"} drives the pin HIGH
// and powers the charging socket for the kiosk timer.
// =====================================================


// =====================================================
// SERIAL
// =====================================================

#define SERIAL_BAUD 115200


// =====================================================
// WATCHDOG / SESSION FAILSAFE
// =====================================================

// If loop() (or a sensor wait) stalls this long, the ESP32
// resets itself. NOTE: relays go OFF on that reset.
#define WDT_TIMEOUT_S 10

// Any session running longer than this is force-aborted.
#define SESSION_MAX_SECONDS 90

void startWatchdog()
{
#if ESP_ARDUINO_VERSION_MAJOR >= 3
  esp_task_wdt_config_t cfg = {
    .timeout_ms = WDT_TIMEOUT_S * 1000,
    .idle_core_mask = 0,
    .trigger_panic = true
  };

  if (esp_task_wdt_init(&cfg) == ESP_ERR_INVALID_STATE)
  {
    esp_task_wdt_reconfigure(&cfg);
  }
#else
  esp_task_wdt_init(WDT_TIMEOUT_S, true);
#endif

  esp_task_wdt_add(NULL);
}


// =====================================================
// RELAY CONFIGURATION
// =====================================================

#define RELAY1_PIN 25
#define RELAY2_PIN 26

// true : LOW = relay ON,  HIGH = relay OFF
// false: HIGH = relay ON, LOW  = relay OFF
#define RELAY_ACTIVE_LOW false


// =====================================================
// I2C / SENSOR CONFIGURATION
// =====================================================

#define SDA_PIN 21
#define SCL_PIN 22
#define MAX30102_ADDR 0x57
#define MLX90614_ADDR 0x5A

// 50 kHz for tolerance of the long wire run to the MLX90614.
#define I2C_CLOCK_HZ 50000

// Max time (ms) a single I2C transaction may block.
#define I2C_TIMEOUT_MS 100


// =====================================================
// MAX30102 CONFIGURATION
// =====================================================

#define BUFFER_SIZE 100
#define FINGER_THRESHOLD 15000

#define SLIDE_AMOUNT 10

#define LED_BRIGHTNESS 60
#define SAMPLE_AVERAGE 4
#define LED_MODE 2
#define SAMPLE_RATE 100
#define PULSE_WIDTH 411
#define ADC_RANGE 4096

#define BPM_HARD_MIN 60
#define BPM_HARD_MAX 200
#define BPM_SOFT_MAX 120

#define SPO2_MIN 70
#define SPO2_MAX 98

#define MAX_COLLECTION_SECONDS 15

#define SAMPLE_TIMEOUT_MS 1500

#define FINGER_WAIT_TIMEOUT_SECONDS 30


// =====================================================
// MLX90614 CONFIGURATION
// =====================================================

#define TEMP_COLLECTION_SECONDS 5
#define MLX_SAMPLE_INTERVAL 300

#define PRESENCE_CHECK_INTERVAL 200

#define PRESENCE_DELTA_C 2.0f

#define TEMP_VALID_MIN_C 30.0f
#define TEMP_VALID_MAX_C 42.0f

#define PRESENCE_TIMEOUT_SECONDS 15

#define TEMP_OFFSET_F 4.0f


// =====================================================
// OBJECTS / BUFFERS
// =====================================================

MAX30105 particleSensor;

uint32_t irBuffer[BUFFER_SIZE];
uint32_t redBuffer[BUFFER_SIZE];


// =====================================================
// STATE
// =====================================================

enum SensorState
{
  STATE_IDLE,
  STATE_WAITING_FINGER,
  STATE_WAITING_OBJECT,
  STATE_COLLECTING,
  STATE_DONE
};

SensorState currentState = STATE_IDLE;

bool sessionMAX = false;
bool sessionTEMP = false;

bool maxSensorOK = false;
bool tempSensorOK = false;

bool quickFingerNotified = false;

bool maxBufferInitialized = false;

bool sensorTimedOut = false;

bool tempStarted = false;


// =====================================================
// RESULT ACCUMULATORS
// =====================================================

float bpmSum = 0.0;
float bpmWeightSum = 0.0;
int bpmCount = 0;

float spo2Sum = 0.0;
int spo2Count = 0;

float objectFSum = 0.0;
float ambientFSum = 0.0;
int tempCount = 0;


// =====================================================
// TIMERS
// =====================================================

unsigned long collectionStart = 0;
unsigned long tempCollectionStart = 0;
unsigned long lastTempSample = 0;
unsigned long presenceWaitStart = 0;
unsigned long fingerWaitStart = 0;
unsigned long sessionStartMs = 0;

int lastMaxSecondReported = -1;
int lastTempSecondReported = -1;


// =====================================================
// FORWARD DECLARATIONS
// =====================================================

void processCommands();
void printStatus(const char* message);


// =====================================================
// RELAY CONTROL
// =====================================================

bool relayPin(uint8_t relay, uint8_t &pin)
{
  if (relay == 1) { pin = RELAY1_PIN; return true; }
  if (relay == 2) { pin = RELAY2_PIN; return true; }
  return false;
}

void setRelay(uint8_t relay, bool state)
{
  uint8_t pin;
  if (!relayPin(relay, pin)) return;

  if (RELAY_ACTIVE_LOW)
    digitalWrite(pin, state ? LOW : HIGH);
  else
    digitalWrite(pin, state ? HIGH : LOW);
}

bool getRelayState(uint8_t relay)
{
  uint8_t pin;
  if (!relayPin(relay, pin)) return false;

  if (RELAY_ACTIVE_LOW)
    return digitalRead(pin) == LOW;
  else
    return digitalRead(pin) == HIGH;
}

void allRelaysOff()
{
  setRelay(1, false);
  setRelay(2, false);
}


// =====================================================
// RELAY JSON RESPONSE / COMMAND
// =====================================================

void sendRelayResponse(
  bool ok,
  uint8_t relay,
  const char* state,
  const char* error = nullptr
)
{
  JsonDocument response;

  response["ok"] = ok;

  if (relay > 0) response["relay"] = relay;
  if (state != nullptr) response["state"] = state;
  if (error != nullptr) response["error"] = error;

  serializeJson(response, Serial);
  Serial.println();
}

void processRelayCommand(JsonDocument &command)
{
  if (!command["relay"].is<int>())
  {
    sendRelayResponse(false, 0, nullptr, "missing_relay");
    return;
  }

  int relay = command["relay"];

  if (relay != 1 && relay != 2)
  {
    sendRelayResponse(false, relay, nullptr, "invalid_relay");
    return;
  }

  if (!command["state"].is<const char*>())
  {
    sendRelayResponse(false, relay, nullptr, "missing_state");
    return;
  }

  const char* state = command["state"];
  bool requestedState;

  if (strcmp(state, "on") == 0)
    requestedState = true;
  else if (strcmp(state, "off") == 0)
    requestedState = false;
  else
  {
    sendRelayResponse(false, relay, nullptr, "invalid_state");
    return;
  }

  setRelay(relay, requestedState);

  bool actualState = getRelayState(relay);

  sendRelayResponse(true, relay, actualState ? "on" : "off");
}


// =====================================================
// I2C BUS RECOVERY
// =====================================================

void startI2C()
{
  Wire.begin(SDA_PIN, SCL_PIN);
  Wire.setClock(I2C_CLOCK_HZ);
  Wire.setTimeOut(I2C_TIMEOUT_MS);
}

void recoverI2CBus()
{
  Wire.end();

  pinMode(SDA_PIN, INPUT_PULLUP);
  pinMode(SCL_PIN, OUTPUT);
  digitalWrite(SCL_PIN, HIGH);
  delayMicroseconds(10);

  for (int i = 0; i < 9; i++)
  {
    digitalWrite(SCL_PIN, LOW);
    delayMicroseconds(10);
    digitalWrite(SCL_PIN, HIGH);
    delayMicroseconds(10);

    if (digitalRead(SDA_PIN) == HIGH) break;
  }

  pinMode(SDA_PIN, OUTPUT);
  digitalWrite(SDA_PIN, LOW);
  delayMicroseconds(10);
  digitalWrite(SCL_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(SDA_PIN, HIGH);
  delayMicroseconds(10);

  startI2C();
}


// =====================================================
// MAX30102 LED CONTROL
// =====================================================

void maxLEDsOn()
{
  particleSensor.setPulseAmplitudeRed(LED_BRIGHTNESS);
  particleSensor.setPulseAmplitudeIR(LED_BRIGHTNESS);
  particleSensor.setPulseAmplitudeGreen(0);

  particleSensor.clearFIFO();
}

void maxLEDsOff()
{
  particleSensor.setPulseAmplitudeRed(0);
  particleSensor.setPulseAmplitudeIR(0);
  particleSensor.setPulseAmplitudeGreen(0);

  particleSensor.clearFIFO();
}


// =====================================================
// RESET SENSOR ACCUMULATORS
// =====================================================

void resetAccumulators()
{
  bpmSum = 0.0;
  bpmWeightSum = 0.0;
  bpmCount = 0;

  spo2Sum = 0.0;
  spo2Count = 0;

  objectFSum = 0.0;
  ambientFSum = 0.0;
  tempCount = 0;

  lastMaxSecondReported = -1;
  lastTempSecondReported = -1;

  quickFingerNotified = false;
  maxBufferInitialized = false;
  sensorTimedOut = false;
  tempStarted = false;
}


// =====================================================
// INITIALIZE / RECOVER MAX30102
// =====================================================

bool initializeMAX30102()
{
  bool ok = particleSensor.begin(
    Wire,
    I2C_SPEED_STANDARD,
    MAX30102_ADDR
  );

  Wire.setClock(I2C_CLOCK_HZ);

  if (!ok)
  {
    return false;
  }

  particleSensor.setup(
    LED_BRIGHTNESS,
    SAMPLE_AVERAGE,
    LED_MODE,
    SAMPLE_RATE,
    PULSE_WIDTH,
    ADC_RANGE
  );

  maxLEDsOff();

  return true;
}

bool recoverMAX30102()
{
  maxSensorOK = initializeMAX30102();

  if (maxSensorOK)
  {
    return true;
  }

  recoverI2CBus();

  maxSensorOK = initializeMAX30102();

  return maxSensorOK;
}


// =====================================================
// READ MLX90614
// =====================================================

float readMLXTemperature(uint8_t reg)
{
  Wire.beginTransmission(MLX90614_ADDR);
  Wire.write(reg);

  if (Wire.endTransmission(false) != 0)
  {
    return NAN;
  }

  int received = Wire.requestFrom(
    (uint8_t)MLX90614_ADDR,
    (uint8_t)3
  );

  if (received < 2)
  {
    return NAN;
  }

  uint8_t lowByte = Wire.read();
  uint8_t highByte = Wire.read();

  if (Wire.available())
  {
    Wire.read();
  }

  uint16_t raw = ((uint16_t)highByte << 8) | lowByte;

  return (raw * 0.02f) - 273.15f;
}

float celsiusToFahrenheit(float c)
{
  return (c * 9.0f / 5.0f) + 32.0f;
}

bool checkMLX90614()
{
  Wire.beginTransmission(MLX90614_ADDR);

  return (Wire.endTransmission() == 0);
}


// =====================================================
// FOREHEAD PRESENCE CHECK
// =====================================================

bool checkForeheadPresent(float &objectCOut, float &ambientCOut)
{
  float objectC = readMLXTemperature(0x07);
  float ambientC = readMLXTemperature(0x06);

  objectCOut = objectC;
  ambientCOut = ambientC;

  if (isnan(objectC) || isnan(ambientC))
  {
    return false;
  }

  return (objectC - ambientC) > PRESENCE_DELTA_C;
}


// =====================================================
// BPM / TEMPERATURE ACCUMULATION
// =====================================================

void accumulateBPM(int32_t bpm)
{
  if (bpm < BPM_HARD_MIN || bpm > BPM_HARD_MAX)
  {
    return;
  }

  float corrected =
    (bpm > BPM_SOFT_MAX)
      ? (float)bpm / 2.0f
      : (float)bpm;

  bpmSum += corrected;
  bpmWeightSum += 1.0f;
  bpmCount++;
}

void accumulateSpO2(int32_t spo2)
{
  if (spo2 > 0 && spo2 >= SPO2_MIN && spo2 <= SPO2_MAX)
  {
    spo2Sum += spo2;
    spo2Count++;
  }
}

void accumulateTempSample()
{
  if (!sessionTEMP || !tempSensorOK)
  {
    return;
  }

  float objectC = readMLXTemperature(0x07);
  float ambientC = readMLXTemperature(0x06);

  if (isnan(objectC) || isnan(ambientC))
  {
    return;
  }

  if (objectC < TEMP_VALID_MIN_C || objectC > TEMP_VALID_MAX_C)
  {
    return;
  }

  objectFSum += celsiusToFahrenheit(objectC);
  ambientFSum += celsiusToFahrenheit(ambientC);

  tempCount++;
}


// =====================================================
// READ MAX30102 SAMPLE (with timeout)
// =====================================================

bool readOneSample(int i)
{
  unsigned long waitStart = millis();

  while (!particleSensor.available())
  {
    particleSensor.check();

    esp_task_wdt_reset();

    delay(1);

    processCommands();

    if (currentState == STATE_IDLE)
    {
      return false;
    }

    if (millis() - waitStart > SAMPLE_TIMEOUT_MS)
    {
      sensorTimedOut = true;
      return false;
    }
  }

  redBuffer[i] = particleSensor.getRed();
  irBuffer[i] = particleSensor.getIR();

  particleSensor.nextSample();

  if (
    currentState == STATE_WAITING_FINGER &&
    !quickFingerNotified &&
    irBuffer[i] > FINGER_THRESHOLD
  )
  {
    printStatus("finger_detected");
    quickFingerNotified = true;
  }

  return true;
}

int countFingerSamples()
{
  int count = 0;

  for (int i = 0; i < BUFFER_SIZE; i++)
  {
    if (irBuffer[i] > FINGER_THRESHOLD)
    {
      count++;
    }
  }

  return count;
}


// =====================================================
// MAX30102 CALCULATION
// =====================================================

bool collectAndComputeMAX(
  int32_t &outBPM,
  int32_t &outSpO2,
  bool &fingerOut
)
{
  outBPM = 0;
  outSpO2 = 0;

  if (!maxBufferInitialized)
  {
    for (int i = 0; i < BUFFER_SIZE; i++)
    {
      if (!readOneSample(i))
      {
        fingerOut = false;
        return false;
      }
    }

    maxBufferInitialized = true;
  }
  else
  {
    for (int i = SLIDE_AMOUNT; i < BUFFER_SIZE; i++)
    {
      redBuffer[i - SLIDE_AMOUNT] = redBuffer[i];
      irBuffer[i - SLIDE_AMOUNT] = irBuffer[i];
    }

    for (int i = BUFFER_SIZE - SLIDE_AMOUNT; i < BUFFER_SIZE; i++)
    {
      if (!readOneSample(i))
      {
        fingerOut = false;
        return false;
      }
    }
  }

  fingerOut = (countFingerSamples() >= 30);

  if (!fingerOut)
  {
    return false;
  }

  int32_t heartRate = 0;
  int8_t validHR = 0;

  int32_t spo2 = 0;
  int8_t validSpO2 = 0;

  maxim_heart_rate_and_oxygen_saturation(
    irBuffer,
    BUFFER_SIZE,
    redBuffer,
    &spo2,
    &validSpO2,
    &heartRate,
    &validHR
  );

  bool gotReading = false;

  if (
    validHR &&
    heartRate >= BPM_HARD_MIN &&
    heartRate <= BPM_HARD_MAX
  )
  {
    outBPM = heartRate;
    gotReading = true;
  }

  if (
    validSpO2 &&
    spo2 >= SPO2_MIN &&
    spo2 <= 100
  )
  {
    outSpO2 = (spo2 > SPO2_MAX) ? SPO2_MAX : spo2;
    gotReading = true;
  }

  return gotReading;
}


// =====================================================
// STATUS / COUNTDOWN / RESULT MESSAGES
// =====================================================

void printStatus(const char* message)
{
  JsonDocument response;

  response["status"] = message;
  response["ts"] = millis();

  serializeJson(response, Serial);
  Serial.println();
}

void printMAXCountdown(int secondsElapsed)
{
  JsonDocument response;

  response["status"] = "recording";
  response["sensor"] = "max30102";
  response["elapsed"] = secondsElapsed;
  response["remaining"] = MAX_COLLECTION_SECONDS - secondsElapsed;
  response["ts"] = millis();

  serializeJson(response, Serial);
  Serial.println();
}

void printTEMPCountdown(int secondsElapsed)
{
  JsonDocument response;

  response["status"] = "recording";
  response["sensor"] = "mlx90614";
  response["elapsed"] = secondsElapsed;
  response["remaining"] = TEMP_COLLECTION_SECONDS - secondsElapsed;
  response["ts"] = millis();

  serializeJson(response, Serial);
  Serial.println();
}

void sendResult()
{
  JsonDocument response;

  float finalBPM =
    (bpmWeightSum > 0.0f)
      ? (bpmSum / bpmWeightSum)
      : 0.0f;

  if (sessionMAX && bpmWeightSum > 0.0f)
    response["bpm"] = finalBPM;
  else
    response["bpm"] = nullptr;

  if (sessionMAX && spo2Count > 0)
    response["spo2"] = spo2Sum / spo2Count;
  else
    response["spo2"] = nullptr;

  if (sessionTEMP && tempCount > 0)
  {
    response["object_f"] = (objectFSum / tempCount) + TEMP_OFFSET_F;
    response["ambient_f"] = ambientFSum / tempCount;
  }
  else
  {
    response["object_f"] = nullptr;
    response["ambient_f"] = nullptr;
  }

  response["status"] = "complete";
  response["ts"] = millis();

  serializeJson(response, Serial);
  Serial.println();
}


// =====================================================
// ABORT / START / STOP SESSION
// =====================================================

void abortSession(const char* reason)
{
  currentState = STATE_IDLE;

  sessionMAX = false;
  sessionTEMP = false;

  maxLEDsOff();

  resetAccumulators();

  JsonDocument response;

  response["status"] = "aborted";
  response["reason"] = reason;
  response["ts"] = millis();

  serializeJson(response, Serial);
  Serial.println();
}

void handleMaxTimeout()
{
  sensorTimedOut = false;

  bool recovered = recoverMAX30102();

  tempSensorOK = checkMLX90614();

  abortSession(recovered ? "max30102_timeout" : "max30102_recovery_failed");
}

void startSession()
{
  if (!sessionMAX && !sessionTEMP)
  {
    printStatus("no_sensor_requested");
    return;
  }

  if (sessionMAX)
  {
    if (!recoverMAX30102())
    {
      Wire.beginTransmission(MAX30102_ADDR);
      uint8_t i2cErr = Wire.endTransmission();

      JsonDocument dbg;
      dbg["status"] = "max30102_not_found";
      dbg["i2c_err"] = i2cErr;
      dbg["ts"] = millis();
      serializeJson(dbg, Serial);
      Serial.println();

      sessionMAX = false;
      sessionTEMP = false;

      return;
    }
  }

  if (sessionTEMP)
  {
    tempSensorOK = checkMLX90614();

    if (!tempSensorOK)
    {
      printStatus("mlx90614_not_found");

      sessionMAX = false;
      sessionTEMP = false;

      return;
    }
  }

  resetAccumulators();

  sessionStartMs = millis();

  if (sessionMAX)
  {
    maxLEDsOn();

    fingerWaitStart = millis();

    currentState = STATE_WAITING_FINGER;

    printStatus("place_finger");
  }
  else
  {
    presenceWaitStart = millis();
    lastTempSample = millis();

    currentState = STATE_WAITING_OBJECT;

    printStatus("place_forehead");
  }
}

void stopSession()
{
  if (currentState == STATE_IDLE)
  {
    printStatus("already_idle");
    return;
  }

  abortSession("user_stop");
}


// =====================================================
// COMMAND HANDLING
// =====================================================

void processJSONCommand(String input)
{
  input.trim();

  if (input.length() == 0)
  {
    return;
  }

  JsonDocument command;

  DeserializationError error = deserializeJson(command, input);

  if (error)
  {
    JsonDocument response;

    response["ok"] = false;
    response["error"] = "invalid_json";

    serializeJson(response, Serial);
    Serial.println();

    return;
  }

  if (
    command["relay"].is<int>() &&
    command["state"].is<const char*>()
  )
  {
    processRelayCommand(command);
    return;
  }

  if (!command["command"].is<const char*>())
  {
    printStatus("unknown_command");
    return;
  }

  const char* cmd = command["command"];

  if (strcmp(cmd, "stop") == 0)
  {
    stopSession();
    return;
  }

  if (strcmp(cmd, "start") == 0)
  {
    if (currentState != STATE_IDLE)
    {
      printStatus("session_in_progress");
      return;
    }

    if (!command["sensor"].is<const char*>())
    {
      printStatus("unknown_sensor");
      return;
    }

    const char* sensor = command["sensor"];

    if (strcmp(sensor, "max30102") == 0)
    {
      sessionMAX = true;
      sessionTEMP = false;
    }
    else if (strcmp(sensor, "mlx90614") == 0)
    {
      sessionMAX = false;
      sessionTEMP = true;
    }
    else if (strcmp(sensor, "all") == 0)
    {
      sessionMAX = true;
      sessionTEMP = true;
    }
    else
    {
      printStatus("unknown_sensor");
      return;
    }

    startSession();
    return;
  }

  printStatus("unknown_command");
}

void processLegacyCommand(String command)
{
  command.trim();
  command.toUpperCase();

  if (
    command == "START MAX" ||
    command == "START TEMP" ||
    command == "START ALL"
  )
  {
    if (currentState != STATE_IDLE)
    {
      printStatus("session_in_progress");
      return;
    }

    sessionMAX = (command == "START MAX" || command == "START ALL");
    sessionTEMP = (command == "START TEMP" || command == "START ALL");

    startSession();
  }
  else if (
    command == "STOP MAX" ||
    command == "STOP TEMP" ||
    command == "STOP ALL" ||
    command == "STOP"
  )
  {
    stopSession();
  }
  else
  {
    printStatus("unknown_command");
  }
}

void dispatchCommand(String &command)
{
  command.trim();

  if (command.length() > 0)
  {
    if (command.startsWith("{"))
      processJSONCommand(command);
    else
      processLegacyCommand(command);
  }

  command = "";
}

void processCommands()
{
  static String command = "";
  static unsigned long lastRxTime = 0;

  while (Serial.available())
  {
    char c = Serial.read();
    lastRxTime = millis();

    if (c == '\n' || c == '\r')
    {
      dispatchCommand(command);
    }
    else
    {
      command += c;

      if (command.length() > 300)
      {
        command = "";
      }
    }
  }

  if (command.length() > 0 && (millis() - lastRxTime) >= 50)
  {
    dispatchCommand(command);
  }
}


// =====================================================
// SETUP
// =====================================================

void setup()
{
  Serial.begin(SERIAL_BAUD);

  delay(1000);

  pinMode(RELAY1_PIN, OUTPUT);
  pinMode(RELAY2_PIN, OUTPUT);

  allRelaysOff();

  startI2C();

  maxSensorOK = initializeMAX30102();

  tempSensorOK = checkMLX90614();

  resetAccumulators();

  currentState = STATE_IDLE;

  sessionMAX = false;
  sessionTEMP = false;

  JsonDocument startup;

  startup["status"] = "ready";
  startup["device"] = "SPPC_CONTROLLER";
  startup["protocol"] = "json_usb";
  startup["baud"] = SERIAL_BAUD;
  startup["reset_reason"] = (int)esp_reset_reason();
  startup["max30102"] = maxSensorOK;
  startup["mlx90614"] = tempSensorOK;
  startup["relay1"] = getRelayState(1);
  startup["relay2"] = getRelayState(2);

  serializeJson(startup, Serial);
  Serial.println();

  startWatchdog();
}


// =====================================================
// MAIN LOOP
// =====================================================

void loop()
{
  esp_task_wdt_reset();

  processCommands();

  if (
    currentState != STATE_IDLE &&
    millis() - sessionStartMs >
      (unsigned long)SESSION_MAX_SECONDS * 1000UL
  )
  {
    abortSession("session_timeout");
    return;
  }

  if (currentState == STATE_WAITING_FINGER)
  {
    int32_t bpm = 0;
    int32_t spo2 = 0;
    bool finger = false;

    collectAndComputeMAX(bpm, spo2, finger);

    if (currentState == STATE_IDLE)
    {
      return;
    }

    if (sensorTimedOut)
    {
      handleMaxTimeout();
      return;
    }

    if (finger)
    {
      collectionStart = millis();

      presenceWaitStart = millis();
      lastTempSample = millis();

      tempStarted = false;

      currentState = STATE_COLLECTING;

      if (!quickFingerNotified)
      {
        printStatus("finger_detected");
        quickFingerNotified = true;
      }

      printStatus("sensor_started");

      accumulateBPM(bpm);
      accumulateSpO2(spo2);
    }
    else if (
      millis() - fingerWaitStart >=
      (unsigned long)FINGER_WAIT_TIMEOUT_SECONDS * 1000UL
    )
    {
      abortSession("no_finger_detected");
      return;
    }
  }

  else if (currentState == STATE_WAITING_OBJECT)
  {
    unsigned long waitElapsed = millis() - presenceWaitStart;

    if (
      waitElapsed >=
      (unsigned long)PRESENCE_TIMEOUT_SECONDS * 1000UL
    )
    {
      abortSession("no_object_detected");
      return;
    }

    if (millis() - lastTempSample >= PRESENCE_CHECK_INTERVAL)
    {
      lastTempSample = millis();

      float objectC = NAN;
      float ambientC = NAN;

      if (checkForeheadPresent(objectC, ambientC))
      {
        tempStarted = true;
        tempCollectionStart = millis();
        lastTempSample = millis();

        currentState = STATE_COLLECTING;

        printStatus("object_detected");
        printStatus("sensor_started");

        accumulateTempSample();
      }
    }
  }

  else if (currentState == STATE_COLLECTING)
  {
    if (sessionMAX && maxSensorOK)
    {
      int32_t bpm = 0;
      int32_t spo2 = 0;
      bool finger = false;

      collectAndComputeMAX(bpm, spo2, finger);

      if (currentState == STATE_IDLE)
      {
        return;
      }

      if (sensorTimedOut)
      {
        handleMaxTimeout();
        return;
      }

      if (!finger)
      {
        abortSession("finger_removed");
        return;
      }

      accumulateBPM(bpm);
      accumulateSpO2(spo2);
    }

    if (sessionTEMP && tempSensorOK)
    {
      if (!tempStarted)
      {
        if (millis() - lastTempSample >= PRESENCE_CHECK_INTERVAL)
        {
          lastTempSample = millis();

          float objectC = NAN;
          float ambientC = NAN;

          if (checkForeheadPresent(objectC, ambientC))
          {
            tempStarted = true;
            tempCollectionStart = millis();

            printStatus("object_detected");

            accumulateTempSample();
          }
        }
      }
      else if (millis() - lastTempSample >= MLX_SAMPLE_INTERVAL)
      {
        accumulateTempSample();

        lastTempSample = millis();
      }
    }

    if (sessionMAX)
    {
      unsigned long maxElapsed = millis() - collectionStart;
      int maxSeconds = (int)(maxElapsed / 1000UL);

      if (
        maxSeconds != lastMaxSecondReported &&
        maxSeconds <= MAX_COLLECTION_SECONDS
      )
      {
        lastMaxSecondReported = maxSeconds;

        printMAXCountdown(maxSeconds);
      }
    }

    if (sessionTEMP && tempStarted)
    {
      unsigned long tempElapsed = millis() - tempCollectionStart;
      int tempSeconds = (int)(tempElapsed / 1000UL);

      if (
        tempSeconds != lastTempSecondReported &&
        tempSeconds <= TEMP_COLLECTION_SECONDS
      )
      {
        lastTempSecondReported = tempSeconds;

        printTEMPCountdown(tempSeconds);
      }
    }

    bool maxDone =
      !sessionMAX ||
      (
        millis() - collectionStart >=
        (unsigned long)MAX_COLLECTION_SECONDS * 1000UL
      );

    bool tempDone;

    if (!sessionTEMP)
    {
      tempDone = true;
    }
    else if (tempStarted)
    {
      tempDone =
        (
          millis() - tempCollectionStart >=
          (unsigned long)TEMP_COLLECTION_SECONDS * 1000UL
        );
    }
    else
    {
      tempDone =
        maxDone &&
        (
          millis() - presenceWaitStart >=
          (unsigned long)PRESENCE_TIMEOUT_SECONDS * 1000UL
        );
    }

    if (maxDone && tempDone)
    {
      currentState = STATE_DONE;
    }
  }

  else if (currentState == STATE_DONE)
  {
    if (sessionMAX)
    {
      maxLEDsOff();
    }

    sendResult();

    currentState = STATE_IDLE;

    sessionMAX = false;
    sessionTEMP = false;

    resetAccumulators();
  }

  if (currentState == STATE_IDLE)
  {
    delay(10);
  }
}

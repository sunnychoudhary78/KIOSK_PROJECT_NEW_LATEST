#include <Wire.h>
#include <ArduinoJson.h>
#include "MAX30105.h"
#include "spo2_algorithm.h"
#include <esp_task_wdt.h>
#include <esp_system.h>
#include <ESP32Servo.h>   // Library Manager -> "ESP32Servo" (Kevin Harrington / John K. Bennett)

// =====================================================
// SPPC ESP32 CONTROLLER
// =====================================================
//
// FUNCTIONS:
// 1. MAX30102 heart rate + SpO2
// 2. MLX90614 temperature
// 3. Relay 1 / Relay 2 control
// 4. USB JSON communication (115200 baud)
// 5. INA226 charger monitor: phone plugged in / plugged out
//    detection, and automatic Relay 1 OFF when the phone is full
// 6. Tray shutter: 20 kg servo -> pinion -> rack, JSON controlled
//    (driven through the ESP32Servo library)
// 7. Printer roller motor (PWM + driver) and a one-command print
//    sequence: {"print":"start"} ... {"print":"done"}
//
// RELAYS: GPIO14 -> Relay 1 (charger), GPIO27 -> Relay 2 (light).
// The roller motor is removed.
// I2C:    GPIO21 -> SDA,     GPIO22 -> SCL
//
// The opto-isolated 2-channel relay board is ACTIVE-LOW (relay pulls
// in when its IN pin is pulled to GND). RELAY_ACTIVE_LOW is therefore
// true, and {"relay":1,"state":"on"} pulls the pin LOW. With
// RELAY_OPEN_DRAIN the OFF state releases the pin (high-Z) instead of
// driving 3.3 V into a 5 V opto input, which can leave the relay
// half-on or on at boot.
//
// SHUTTER: GPIO13 (D13) -> servo signal. See the SHUTTER CONFIGURATION block.
//   {"shutter":"open"} {"shutter":"close"} {"shutter":"status"}
//   {"shutter_angle":90}   (calibration, moves straight there)
//   {"shutter_set":"open","angle":120}  / "close"  (RAM only)
//   {"shutter_us":1500}    (raw pulse width, for continuous servos)
//   Continuous servo tuning: {"shutter_set":"stop"|"speed"|"travel"|"dir",
//                             "value":N}
//
// SERVO TEST (do this first if the shutter does nothing):
//   {"shutter_us":1700}  -> spins one way   = continuous servo
//   {"shutter_us":1300}  -> spins other way
//   {"shutter_us":1500}  -> stops
//   {"shutter_us":0}     -> releases the servo
//   If it instead jumps to a position and stays, it is a POSITION
//   servo: set SHUTTER_CONTINUOUS to false.
//
// PRINT SEQUENCE (what kiosk.exe sends):
//   {"print":"start"}  -> PRINT_START_DELAY_MS later: shutter opens and
//                         the roller motor starts
//   {"print":"done"}   -> PRINT_END_DELAY_MS later: motor stops and the
//                         shutter closes
//   {"print":"stop"}   -> stop motor + close shutter immediately
//   {"print":"status"}
//   MOTOR: {"motor":"on"} {"motor":"off"} {"motor_speed":80}
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

bool watchdogRunning = false;

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

  watchdogRunning = true;
}


// =====================================================
// RELAY CONFIGURATION
// =====================================================

#define RELAY1_PIN 14   // charger relay (Relay 1)
#define RELAY2_PIN 27   // light relay (Relay 2). -1 = not used

// true : LOW = relay ON,  HIGH = relay OFF
// false: HIGH = relay ON, LOW  = relay OFF
// Bench test: unplug the ESP32 wire from IN1 and touch IN1 to GND.
// Relay clicks ON -> active-low (true). Clicks OFF -> set false.
#define RELAY_ACTIVE_LOW true

// Only used when RELAY_ACTIVE_LOW is true. OFF = release the pin
// (input / high-Z) so 3.3 V logic cannot half-drive a 5 V opto input.
#define RELAY_OPEN_DRAIN false


// =====================================================
// SHUTTER CONFIGURATION
// =====================================================

// Servo signal pin = D13 / GPIO13 (21/22 = I2C, 25/26 = relays)
#define SHUTTER_PIN 13

// false: 360-degree POSITION servo (angle commands)
// true : CONTINUOUS rotation servo (timed moves, no position feedback)
// Now set to POSITION mode: open = SHUTTER_OPEN_DEG, close = 0 deg.
#define SHUTTER_CONTINUOUS false

// --- position servo ---
// Pulse width that maps to 0 and to SHUTTER_RANGE_DEG. Most 360 deg
// digital servos use 500-2500 us for the full turn. If your servo only
// turns 180 or 270 deg over this pulse range, change SHUTTER_RANGE_DEG.
#define SHUTTER_RANGE_DEG 360
#define SHUTTER_MIN_US 500
#define SHUTTER_MAX_US 2500

// Servo angles for closed / open. START WITH SMALL VALUES and calibrate
// with {"shutter_angle":N} so the rack never hits the end of its guide.
#define SHUTTER_CLOSED_DEG 0

// Direction. Open (0 -> 180 deg) should turn ANTICLOCKWISE and close
// (180 -> 0 deg) CLOCKWISE, seen from the servo horn side.
// If it turns the wrong way, change this to true.
#define SHUTTER_REVERSE false
#define SHUTTER_OPEN_DEG 160

// Travel speed and update interval (slow = gentle on the printed gear)
#define SHUTTER_SPEED_DEG_S 600
#define SHUTTER_STEP_MS 10

// --- continuous servo (DEFAULTS; tune live, see the commands below) ---
//   {"shutter_set":"stop","value":1500}    pulse where it stands still
//   {"shutter_set":"speed","value":150}    us away from stop (bigger = faster)
//   {"shutter_set":"travel","value":1500}  ms of running per open / close
//   {"shutter_set":"dir","value":-1}       swap open / close direction
// There is no position feedback: distance = speed x time.
#define SHUTTER_CONT_STOP_US 1500
#define SHUTTER_CONT_SPEED_US 150
#define SHUTTER_CONT_OPEN_DIR 1
#define SHUTTER_CONT_TRAVEL_MS 1500

// Shutter closes by itself this long after opening (0 = never).
// Failsafe only if the host app forgets to close it. Keep it LONGER
// than PRINT_MAX_S so it never closes in the middle of a print.
#define SHUTTER_AUTO_CLOSE_S 300

// Position servo only: release the servo this long after it has closed
// (0 = keep holding forever). The shutter is always held while OPEN so
// gravity cannot drop it.
#define SHUTTER_DETACH_CLOSED_MS 0


// =====================================================
// ROLLER MOTOR CONFIGURATION
// =====================================================
//
// The printer's brushed DC roller motor is driven through a motor
// driver / MOSFET board with its OWN supply (never from an ESP32 pin).
// Join the driver ground to the ESP32 ground.
//
//   MOTOR_PWM_PIN  -> driver PWM / EN input (speed)
//   MOTOR_DIR_PIN  -> driver IN1 (direction). -1 if not used.
//   MOTOR_DIR2_PIN -> driver IN2 (gets the opposite level of IN1,
//                     for L298N-style boards). -1 if not used.
//
// L298N module wiring (red board):
//   GPIO32 -> ENA   (REMOVE the jumper cap on ENA, or PWM does nothing)
//   GPIO33 -> IN1
//   GPIO18 -> IN2
//   motor  -> OUT1 / OUT2
//   supply + -> 12V terminal, supply - -> GND, ESP32 GND -> same GND
// Roller motor REMOVED. Set MOTOR_ENABLED true and restore the pins to use it again.
#define MOTOR_ENABLED false
#define MOTOR_PWM_PIN -1
#define MOTOR_DIR_PIN -1
#define MOTOR_DIR2_PIN -1

// Level on MOTOR_DIR_PIN that rolls the paper OUT of the machine.
// If the rollers turn the wrong way, change HIGH to LOW.
#define MOTOR_FORWARD_LEVEL HIGH

// Speed while running (percent) and soft start / soft stop time.
// L298N drops about 2 V, so for a 6 V motor:
//   duty % = 6 / (supply volts - 2) * 100
//   8 V -> 100,  9 V -> 86,  12 V -> 60
#define MOTOR_SPEED_PCT 50
#define MOTOR_RAMP_MS 400

// Motor is forced off after this long, whatever the host does
#define MOTOR_MAX_RUN_S 300


// =====================================================
// PRINT SEQUENCE CONFIGURATION
// =====================================================

// {"print":"start"} -> wait this long, then open shutter + start motor
#define PRINT_START_DELAY_MS 3000

// {"print":"done"}  -> wait this long, then stop motor + close shutter
#define PRINT_END_DELAY_MS 5000

// Whole sequence is aborted (motor off, shutter closed) after this long
// if "done" never arrives (app crash, printer jam, cable pulled...).
#define PRINT_MAX_S 240


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

#define SPO2_MIN 70
#define SPO2_MAX 100

#define MAX_COLLECTION_SECONDS 15
// Extra collect window when finger stays on but SpO2 never accumulated.
#define MAX_SPO2_EXTEND_SECONDS 12

#define SAMPLE_TIMEOUT_MS 1500

#define FINGER_WAIT_TIMEOUT_SECONDS 30


// =====================================================
// MLX90614 CONFIGURATION
// =====================================================

#define TEMP_COLLECTION_SECONDS 5
#define MLX_SAMPLE_INTERVAL 300

#define PRESENCE_CHECK_INTERVAL 200

// LONG-DISTANCE (1.5-2 cm+) TUNING
// At distance the sensor's field of view includes more background, so
// the raw object temperature reads LOWER than the real skin temperature.
//
// PRESENCE_DELTA_C   : (object - ambient) needed to detect a forehead.
//                      Was 2.0 (close range); lowered for distance.
// PRESENCE_CONFIRM_COUNT : consecutive hits needed, so the lower
//                      threshold doesn't trigger on noise.
// TEMP_RAW_MIN_C     : lowest RAW object temp accepted (before gain).
// TEMP_DISTANCE_GAIN : scales (object - ambient) back up to compensate
//                      for the distance. 1.0 = no compensation.
//                      Tune against a reference thermometer.
#define PRESENCE_DELTA_C 0.5f
#define PRESENCE_CONFIRM_COUNT 3

// After the forehead is detected (from ~6-7 cm), wait this long before
// the measurement actually starts, so the person can settle/move closer.
#define TEMP_SETTLE_MS 2000

#define TEMP_RAW_MIN_C 24.0f

#define TEMP_DISTANCE_GAIN 1.35f

// Valid range applies to the distance-corrected temperature.
#define TEMP_VALID_MIN_C 30.0f
#define TEMP_VALID_MAX_C 42.0f

#define PRESENCE_TIMEOUT_SECONDS 15

#define TEMP_OFFSET_F 4.0f


// =====================================================
// INA226 / CHARGER MONITOR CONFIGURATION
// =====================================================
//
// The INA226 sits on the same I2C bus (GPIO21/22) and measures the
// charging line. While the charger relay is ON the ESP32 watches the
// power drawn:
//   - power rises above PLUG_ON_W   -> phone plugged in
//   - power drops abruptly to ~0    -> phone plugged out, relay OFF
//   - power tapers off and stays low for FULL_HOLD_S seconds
//                                   -> phone fully charged, relay OFF
//
// NOTE: with the relay OFF the charging module has no power, so
// plug in / plug out can only be detected while the relay is ON.

// Relay that powers the charging module / socket
#define CHARGER_RELAY 1

// INA226 I2C address (A0 = A1 = GND -> 0x40)
#define INA226_ADDR 0x40

// Value of the shunt resistor on YOUR INA226 module, in ohms.
// Printed on the module: R100 = 0.1, R010 = 0.01, R002 = 0.002.
// The INA226 can only measure +/-81.92 mV across the shunt,
// so max current = 0.08192 / SHUNT_OHMS (0.01 ohm -> 8.19 A).
#define INA226_SHUNT_OHMS 0.01f

#define INA226_REG_CONFIG 0x00
#define INA226_REG_SHUNT 0x01
#define INA226_REG_BUS 0x02
#define INA226_REG_MANUF_ID 0xFE

// 16 sample averaging, 1.1 ms conversions, continuous mode
#define INA226_CONFIG_VALUE 0x4527

// How often the charger is checked (ms)
#define CHARGER_POLL_MS 500

// Ignore readings for this long after the relay turns ON (inrush)
#define CHARGER_SETTLE_MS 3000

// If polling was paused longer than this (e.g. during a MAX30102
// session) the plug in / plug out debounce counters restart.
#define CHARGER_GAP_MS 3000

// Retry interval when the INA226 is not responding
#define CHARGER_REINIT_MS 5000

// POWER THRESHOLDS (watts, measured by the INA226)
// Tune these with CHARGER_DEBUG_STREAM (see below).
//   PLUG_ON_W  : above this for PLUG_CONFIRM samples = phone plugged in
//   PLUG_OFF_W : below this = nothing drawing power
//   FULL_W     : below this = charge has tapered off (almost full)
#define CHARGER_PLUG_ON_W 2.0f
#define CHARGER_PLUG_OFF_W 0.8f
#define CHARGER_FULL_W 3.0f

// Samples (x CHARGER_POLL_MS) needed to confirm plug in / plug out
// DETECTION MODE
// true : decide plugged in / out / full from the CURRENT (mA). Works
//        even when the INA226 VBUS pin is not wired (volts read 0).
// false: decide from POWER (watts = volts x mA). Needs VBUS wired.
#define CHARGER_USE_CURRENT true

// Current thresholds (mA), used when CHARGER_USE_CURRENT is true.
// Measured: nothing connected = 0-2 mA, phone connected = 60+ mA.
//   PLUG_ON_MA  : above this for PLUG_CONFIRM samples = phone plugged in
//   PLUG_OFF_MA : below this = nothing drawing current
//   FULL_MA     : below this = charge has tapered off (almost full)
#define CHARGER_PLUG_ON_MA 30.0f
#define CHARGER_PLUG_OFF_MA 10.0f
#define CHARGER_FULL_MA 25.0f

#if CHARGER_USE_CURRENT
  #define CH_PLUG_ON  CHARGER_PLUG_ON_MA
  #define CH_PLUG_OFF CHARGER_PLUG_OFF_MA
  #define CH_FULL     CHARGER_FULL_MA
#else
  #define CH_PLUG_ON  CHARGER_PLUG_ON_W
  #define CH_PLUG_OFF CHARGER_PLUG_OFF_W
  #define CH_FULL     CHARGER_FULL_W
#endif

#define CHARGER_PLUG_CONFIRM 3
#define CHARGER_UNPLUG_CONFIRM 4

// A drop below PLUG_OFF_W counts as "unplugged" only if the power was
// above FULL_W within the last ABRUPT_SAMPLES samples. A slow taper to
// zero is treated as the end of charging instead.
#define CHARGER_ABRUPT_SAMPLES 8

// Power must stay below FULL_W this long to call the phone full.
#define CHARGER_FULL_HOLD_S 60
#define CHARGER_FULL_HOLD_SAMPLES ((CHARGER_FULL_HOLD_S * 1000) / CHARGER_POLL_MS)

// Safety: relay is switched OFF after this long on one phone.
#define CHARGER_MAX_MINUTES 240

// true: print a {"charger":"debug",...} line every 2 s with the
// live volts / mA / watts, to tune the thresholds above.
#define CHARGER_DEBUG_STREAM false


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
int validSpO2Hits = 0;
bool lastFingerPresent = false;
bool maxSpO2ExtendUsed = false;
unsigned long maxCollectionMs = (unsigned long)MAX_COLLECTION_SECONDS * 1000UL;

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

bool relayLogicalState[3] = { false, false, false };

bool relayPin(uint8_t relay, uint8_t &pin)
{
  if (relay == 1) { pin = RELAY1_PIN; return true; }
  if (relay == 2 && RELAY2_PIN >= 0) { pin = RELAY2_PIN; return true; }
  return false;
}

void relayDrive(uint8_t pin, bool on)
{
  if (RELAY_ACTIVE_LOW)
  {
    if (on)
    {
      pinMode(pin, OUTPUT);
      digitalWrite(pin, LOW);
    }
    else if (RELAY_OPEN_DRAIN)
    {
      pinMode(pin, INPUT);
    }
    else
    {
      pinMode(pin, OUTPUT);
      digitalWrite(pin, HIGH);
    }
  }
  else
  {
    pinMode(pin, OUTPUT);
    digitalWrite(pin, on ? HIGH : LOW);
  }
}

void setRelay(uint8_t relay, bool state)
{
  uint8_t pin;
  if (!relayPin(relay, pin)) return;

  relayDrive(pin, state);
  relayLogicalState[relay] = state;
}

bool getRelayState(uint8_t relay)
{
  uint8_t pin;
  if (!relayPin(relay, pin)) return false;

  return relayLogicalState[relay];
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

  if (relay != 1 && !(relay == 2 && RELAY2_PIN >= 0))
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
// SHUTTER CONTROL (servo + pinion + rack)
// =====================================================

enum ShutterState
{
  SHUTTER_CLOSED,
  SHUTTER_OPENING,
  SHUTTER_OPEN,
  SHUTTER_CLOSING
};

ShutterState shutterState = SHUTTER_CLOSED;

// ESP32Servo object. Pulses are written in microseconds, which works
// for both position and continuous-rotation servos.
Servo shutterServo;

bool shutterPwmOn = false;
bool shutterManual = false;

float shutterAngle = SHUTTER_CLOSED_DEG;
float shutterTarget = SHUTTER_CLOSED_DEG;
float shutterOpenDeg = SHUTTER_OPEN_DEG;
float shutterClosedDeg = SHUTTER_CLOSED_DEG;

unsigned long shutterLastStep = 0;
unsigned long shutterOpenedAt = 0;
unsigned long shutterIdleSince = 0;
unsigned long shutterContEnd = 0;

int shutterContStopUs = SHUTTER_CONT_STOP_US;
int shutterContSpeedUs = SHUTTER_CONT_SPEED_US;
int shutterContDir = SHUTTER_CONT_OPEN_DIR;
unsigned long shutterContTravelMs = SHUTTER_CONT_TRAVEL_MS;

const char* shutterStateName()
{
  switch (shutterState)
  {
    case SHUTTER_OPENING: return "opening";
    case SHUTTER_OPEN:    return "open";
    case SHUTTER_CLOSING: return "closing";
    default:              return "closed";
  }
}

// Send a servo pulse of `us` microseconds (attaches the servo the
// first time it is used).
void shutterPwmWriteUs(uint32_t us)
{
  if (us < 500) us = 500;
  if (us > 2500) us = 2500;

  if (!shutterPwmOn)
  {
    shutterServo.setPeriodHertz(50);
    shutterServo.attach(SHUTTER_PIN, 500, 2500);
    shutterPwmOn = true;
  }

  shutterServo.writeMicroseconds((int)us);
}

// Stop sending pulses and hold the signal pin LOW.
void shutterPwmOff()
{
  if (!shutterPwmOn) return;

  shutterServo.detach();
  shutterPwmOn = false;

  pinMode(SHUTTER_PIN, OUTPUT);
  digitalWrite(SHUTTER_PIN, LOW);
}

uint32_t shutterAngleToUs(float deg)
{
  if (deg < 0.0f) deg = 0.0f;
  if (deg > (float)SHUTTER_RANGE_DEG) deg = (float)SHUTTER_RANGE_DEG;

  float span = (float)(SHUTTER_MAX_US - SHUTTER_MIN_US);
  float frac = deg / (float)SHUTTER_RANGE_DEG;

  if (SHUTTER_REVERSE)
    return (uint32_t)((float)SHUTTER_MAX_US - frac * span);

  return (uint32_t)((float)SHUTTER_MIN_US + frac * span);
}

void shutterBegin()
{
  pinMode(SHUTTER_PIN, OUTPUT);
  digitalWrite(SHUTTER_PIN, LOW);

  shutterState = SHUTTER_CLOSED;
  shutterIdleSince = millis();

  // A continuous servo has no position feedback, so there is nothing
  // to home. A position servo is driven to the closed angle at boot.
  if (!SHUTTER_CONTINUOUS)
  {
    shutterAngle = shutterClosedDeg;
    shutterTarget = shutterClosedDeg;
    shutterPwmWriteUs(shutterAngleToUs(shutterAngle));
  }
}

void shutterMove(bool open)
{
  if (open && (shutterState == SHUTTER_OPEN || shutterState == SHUTTER_OPENING))
    return;

  if (!open && (shutterState == SHUTTER_CLOSED || shutterState == SHUTTER_CLOSING))
    return;

  shutterManual = false;
  shutterState = open ? SHUTTER_OPENING : SHUTTER_CLOSING;

  if (SHUTTER_CONTINUOUS)
  {
    int dir = open ? shutterContDir : -shutterContDir;

    shutterPwmWriteUs(shutterContStopUs + dir * shutterContSpeedUs);
    shutterContEnd = millis() + shutterContTravelMs;
  }
  else
  {
    shutterTarget = open ? shutterOpenDeg : shutterClosedDeg;
    shutterLastStep = millis();

    shutterPwmWriteUs(shutterAngleToUs(shutterAngle));
  }

  printStatus(open ? "shutter_opening" : "shutter_closing");
}

void shutterFinished()
{
  unsigned long now = millis();

  if (shutterState == SHUTTER_OPENING)
  {
    shutterState = SHUTTER_OPEN;
    shutterOpenedAt = now;
    printStatus("shutter_open");
  }
  else
  {
    shutterState = SHUTTER_CLOSED;
    shutterIdleSince = now;
    printStatus("shutter_closed");
  }

  if (SHUTTER_CONTINUOUS)
  {
    shutterPwmOff();
  }
}

// Non-blocking. Called every loop().
void shutterUpdate()
{
  unsigned long now = millis();

  if (shutterState == SHUTTER_OPENING || shutterState == SHUTTER_CLOSING)
  {
    if (SHUTTER_CONTINUOUS)
    {
      if ((long)(now - shutterContEnd) >= 0)
      {
        shutterPwmWriteUs(shutterContStopUs);
        shutterFinished();
      }
    }
    else if (now - shutterLastStep >= SHUTTER_STEP_MS)
    {
      float step =
        (float)SHUTTER_SPEED_DEG_S * (float)(now - shutterLastStep) / 1000.0f;

      shutterLastStep = now;

      if (fabsf(shutterTarget - shutterAngle) <= step)
        shutterAngle = shutterTarget;
      else
        shutterAngle += (shutterTarget > shutterAngle) ? step : -step;

      shutterPwmWriteUs(shutterAngleToUs(shutterAngle));

      if (shutterAngle == shutterTarget)
      {
        shutterFinished();
      }
    }

    return;
  }

  if (
    SHUTTER_AUTO_CLOSE_S > 0 &&
    shutterState == SHUTTER_OPEN &&
    !shutterManual &&
    now - shutterOpenedAt >= (unsigned long)SHUTTER_AUTO_CLOSE_S * 1000UL
  )
  {
    printStatus("shutter_auto_close");
    shutterMove(false);
    return;
  }

  if (
    !SHUTTER_CONTINUOUS &&
    SHUTTER_DETACH_CLOSED_MS > 0 &&
    shutterState == SHUTTER_CLOSED &&
    shutterPwmOn &&
    now - shutterIdleSince >= (unsigned long)SHUTTER_DETACH_CLOSED_MS
  )
  {
    shutterPwmOff();
  }
}

void sendShutterResponse(bool ok, const char* error = nullptr)
{
  JsonDocument response;

  response["ok"] = ok;
  response["shutter"] = shutterStateName();

  if (!SHUTTER_CONTINUOUS)
  {
    response["angle"] = (int)(shutterAngle + 0.5f);
    response["open_deg"] = (int)(shutterOpenDeg + 0.5f);
    response["closed_deg"] = (int)(shutterClosedDeg + 0.5f);
  }
  else
  {
    response["stop_us"] = shutterContStopUs;
    response["speed_us"] = shutterContSpeedUs;
    response["travel_ms"] = (unsigned long)shutterContTravelMs;
    response["dir"] = shutterContDir;
  }

  if (error != nullptr) response["error"] = error;

  serializeJson(response, Serial);
  Serial.println();
}

void processShutterCommand(JsonDocument &command)
{
  // {"shutter":"open" | "close" | "status"}
  if (command["shutter"].is<const char*>())
  {
    const char* action = command["shutter"];

    if (strcmp(action, "open") == 0)
    {
      shutterMove(true);
    }
    else if (strcmp(action, "close") == 0)
    {
      shutterMove(false);
    }
    else if (strcmp(action, "status") != 0)
    {
      sendShutterResponse(false, "invalid_shutter_action");
      return;
    }

    sendShutterResponse(true);
    return;
  }

  // {"shutter_angle":N}  calibration: go straight to N degrees
  if (!command["shutter_angle"].isNull())
  {
    if (SHUTTER_CONTINUOUS)
    {
      sendShutterResponse(false, "continuous_servo_use_shutter_us");
      return;
    }

    float a = command["shutter_angle"].as<float>();

    if (a < 0.0f) a = 0.0f;
    if (a > (float)SHUTTER_RANGE_DEG) a = (float)SHUTTER_RANGE_DEG;

    shutterManual = true;
    shutterAngle = a;
    shutterTarget = a;
    shutterState =
      (fabsf(a - shutterClosedDeg) < 1.0f) ? SHUTTER_CLOSED : SHUTTER_OPEN;
    shutterOpenedAt = millis();
    shutterIdleSince = millis();

    shutterPwmWriteUs(shutterAngleToUs(a));

    sendShutterResponse(true);
    return;
  }

  // {"shutter_us":N}  raw pulse width; 0 releases the servo
  if (!command["shutter_us"].isNull())
  {
    int us = command["shutter_us"].as<int>();

    shutterManual = true;

    if (us <= 0)
      shutterPwmOff();
    else
      shutterPwmWriteUs((uint32_t)us);

    sendShutterResponse(true);
    return;
  }

  // {"shutter_set":"open"|"close","angle":N}  runtime angle (RAM only)
  if (command["shutter_set"].is<const char*>())
  {
    const char* which = command["shutter_set"];

    if (
      strcmp(which, "stop") == 0 ||
      strcmp(which, "speed") == 0 ||
      strcmp(which, "travel") == 0 ||
      strcmp(which, "dir") == 0
    )
    {
      if (command["value"].isNull())
      {
        sendShutterResponse(false, "missing_value");
        return;
      }

      int v = command["value"].as<int>();

      if (strcmp(which, "stop") == 0)
        shutterContStopUs = constrain(v, 1300, 1700);
      else if (strcmp(which, "speed") == 0)
        shutterContSpeedUs = constrain(v, 20, 500);
      else if (strcmp(which, "travel") == 0)
        shutterContTravelMs = (unsigned long)constrain(v, 100, 10000);
      else
        shutterContDir = (v < 0) ? -1 : 1;

      sendShutterResponse(true);
      return;
    }

    if (command["angle"].isNull())
    {
      sendShutterResponse(false, "missing_angle");
      return;
    }

    float a = command["angle"].as<float>();

    if (a < 0.0f) a = 0.0f;
    if (a > (float)SHUTTER_RANGE_DEG) a = (float)SHUTTER_RANGE_DEG;

    if (strcmp(which, "open") == 0)
      shutterOpenDeg = a;
    else if (strcmp(which, "close") == 0)
      shutterClosedDeg = a;
    else
    {
      sendShutterResponse(false, "invalid_shutter_set");
      return;
    }

    sendShutterResponse(true);
    return;
  }

  sendShutterResponse(false, "invalid_shutter_command");
}


// =====================================================
// ROLLER MOTOR CONTROL
// =====================================================

#define MOTOR_PWM_HZ 20000
#define MOTOR_PWM_BITS 10
#define MOTOR_PWM_CH 6

bool motorPwmAttached = false;
bool motorRunning = false;

float motorCurPct = 0.0f;
float motorTargetPct = 0.0f;
float motorSpeedPct = MOTOR_SPEED_PCT;

unsigned long motorLastStep = 0;
unsigned long motorStartedAt = 0;

void motorPwmWritePct(float pct)
{
  if (pct < 0.0f) pct = 0.0f;
  if (pct > 100.0f) pct = 100.0f;

  uint32_t duty =
    (uint32_t)((pct / 100.0f) * (float)((1UL << MOTOR_PWM_BITS) - 1));

#if ESP_ARDUINO_VERSION_MAJOR >= 3
  if (!motorPwmAttached)
  {
    ledcAttach(MOTOR_PWM_PIN, MOTOR_PWM_HZ, MOTOR_PWM_BITS);
    motorPwmAttached = true;
  }
  ledcWrite(MOTOR_PWM_PIN, duty);
#else
  if (!motorPwmAttached)
  {
    ledcSetup(MOTOR_PWM_CH, MOTOR_PWM_HZ, MOTOR_PWM_BITS);
    ledcAttachPin(MOTOR_PWM_PIN, MOTOR_PWM_CH);
    motorPwmAttached = true;
  }
  ledcWrite(MOTOR_PWM_CH, duty);
#endif
}

void motorDirIdle()
{
  if (MOTOR_DIR_PIN >= 0) digitalWrite(MOTOR_DIR_PIN, LOW);
  if (MOTOR_DIR2_PIN >= 0) digitalWrite(MOTOR_DIR2_PIN, LOW);
}

void motorDirForward()
{
  if (MOTOR_DIR_PIN >= 0)
    digitalWrite(MOTOR_DIR_PIN, MOTOR_FORWARD_LEVEL);

  if (MOTOR_DIR2_PIN >= 0)
    digitalWrite(MOTOR_DIR2_PIN, MOTOR_FORWARD_LEVEL ? LOW : HIGH);
}

void motorPwmRelease()
{
  if (motorPwmAttached)
  {
#if ESP_ARDUINO_VERSION_MAJOR >= 3
    ledcDetach(MOTOR_PWM_PIN);
#else
    ledcDetachPin(MOTOR_PWM_PIN);
#endif
    motorPwmAttached = false;
  }

  pinMode(MOTOR_PWM_PIN, OUTPUT);
  digitalWrite(MOTOR_PWM_PIN, LOW);

  motorDirIdle();
}

void motorBegin()
{
  if (!MOTOR_ENABLED) return;

  pinMode(MOTOR_PWM_PIN, OUTPUT);
  digitalWrite(MOTOR_PWM_PIN, LOW);

  if (MOTOR_DIR_PIN >= 0) pinMode(MOTOR_DIR_PIN, OUTPUT);
  if (MOTOR_DIR2_PIN >= 0) pinMode(MOTOR_DIR2_PIN, OUTPUT);

  motorDirIdle();
}

void motorStart()
{
  if (!MOTOR_ENABLED) return;

  if (!motorRunning)
  {
    motorRunning = true;
    motorStartedAt = millis();
    motorLastStep = millis();

    motorDirForward();

    printStatus("motor_on");
  }

  motorTargetPct = motorSpeedPct;
}

void motorStop()
{
  if (motorRunning)
  {
    motorRunning = false;
    motorLastStep = millis();

    printStatus("motor_off");
  }

  motorTargetPct = 0.0f;
}

// Non-blocking soft start / soft stop. Called every loop().
void motorUpdate()
{
  if (!MOTOR_ENABLED) return;

  unsigned long now = millis();

  if (
    motorRunning &&
    MOTOR_MAX_RUN_S > 0 &&
    now - motorStartedAt >= (unsigned long)MOTOR_MAX_RUN_S * 1000UL
  )
  {
    printStatus("motor_timeout");
    motorStop();
  }

  if (motorCurPct != motorTargetPct && now - motorLastStep >= 10)
  {
    float step = 100.0f * (float)(now - motorLastStep) / (float)MOTOR_RAMP_MS;

    motorLastStep = now;

    if (fabsf(motorTargetPct - motorCurPct) <= step)
      motorCurPct = motorTargetPct;
    else
      motorCurPct += (motorTargetPct > motorCurPct) ? step : -step;

    motorPwmWritePct(motorCurPct);
  }

  if (!motorRunning && motorCurPct == 0.0f && motorPwmAttached)
  {
    motorPwmRelease();
  }
}

void sendMotorResponse(bool ok, const char* error = nullptr)
{
  JsonDocument response;

  response["ok"] = ok;
  response["motor"] = motorRunning ? "on" : "off";
  response["speed"] = (int)(motorSpeedPct + 0.5f);

  if (error != nullptr) response["error"] = error;

  serializeJson(response, Serial);
  Serial.println();
}

void processMotorCommand(JsonDocument &command)
{
  if (!MOTOR_ENABLED)
  {
    sendMotorResponse(false, "motor_disabled");
    return;
  }

  if (command["motor"].is<const char*>())
  {
    const char* action = command["motor"];

    if (strcmp(action, "on") == 0)
    {
      motorStart();
    }
    else if (strcmp(action, "off") == 0)
    {
      motorStop();
    }
    else if (strcmp(action, "status") != 0)
    {
      sendMotorResponse(false, "invalid_motor_action");
      return;
    }

    sendMotorResponse(true);
    return;
  }

  if (!command["motor_speed"].isNull())
  {
    float v = command["motor_speed"].as<float>();

    if (v < 0.0f) v = 0.0f;
    if (v > 100.0f) v = 100.0f;

    motorSpeedPct = v;

    if (motorRunning) motorTargetPct = motorSpeedPct;

    sendMotorResponse(true);
    return;
  }

  sendMotorResponse(false, "invalid_motor_command");
}


// =====================================================
// PRINT SEQUENCE (shutter + roller motor)
// =====================================================

enum PrintSeqState
{
  PSEQ_IDLE,
  PSEQ_WAIT_START,
  PSEQ_RUNNING,
  PSEQ_WAIT_END
};

PrintSeqState printSeq = PSEQ_IDLE;

unsigned long printSeqAt = 0;
unsigned long printSeqStartedAt = 0;
bool printDonePending = false;

const char* printSeqName()
{
  switch (printSeq)
  {
    case PSEQ_WAIT_START: return "waiting_start";
    case PSEQ_RUNNING:    return "running";
    case PSEQ_WAIT_END:   return "waiting_end";
    default:              return "idle";
  }
}

void sendPrintResponse(bool ok, const char* error = nullptr)
{
  JsonDocument response;

  response["ok"] = ok;
  response["print"] = printSeqName();
  response["shutter"] = shutterStateName();
  response["motor"] = motorRunning ? "on" : "off";

  if (error != nullptr) response["error"] = error;

  serializeJson(response, Serial);
  Serial.println();
}

void printSeqEnd(const char* reason)
{
  motorStop();
  shutterMove(false);

  printSeq = PSEQ_IDLE;
  printDonePending = false;

  printStatus(reason);
}

void processPrintCommand(JsonDocument &command)
{
  if (!command["print"].is<const char*>())
  {
    sendPrintResponse(false, "invalid_print_command");
    return;
  }

  const char* action = command["print"];
  unsigned long now = millis();

  if (strcmp(action, "start") == 0)
  {
    if (printSeq == PSEQ_IDLE)
    {
      printSeq = PSEQ_WAIT_START;
      printSeqAt = now + PRINT_START_DELAY_MS;
      printSeqStartedAt = now;
      printDonePending = false;

      printStatus("print_sequence_waiting");
    }
    else if (printSeq == PSEQ_WAIT_END)
    {
      // A new job arrived before the shutter closed: keep going.
      printSeq = PSEQ_RUNNING;
      printDonePending = false;
    }
  }
  else if (strcmp(action, "done") == 0)
  {
    if (printSeq == PSEQ_WAIT_START)
    {
      printDonePending = true;
    }
    else if (printSeq == PSEQ_RUNNING)
    {
      printSeq = PSEQ_WAIT_END;
      printSeqAt = now + PRINT_END_DELAY_MS;
    }
  }
  else if (strcmp(action, "stop") == 0)
  {
    printSeqEnd("print_sequence_stopped");
  }
  else if (strcmp(action, "status") != 0)
  {
    sendPrintResponse(false, "invalid_print_action");
    return;
  }

  sendPrintResponse(true);
}

// Non-blocking. Called every loop().
void printSeqUpdate()
{
  if (printSeq == PSEQ_IDLE) return;

  unsigned long now = millis();

  if (now - printSeqStartedAt >= (unsigned long)PRINT_MAX_S * 1000UL)
  {
    printSeqEnd("print_failsafe");
    return;
  }

  if (printSeq == PSEQ_WAIT_START && (long)(now - printSeqAt) >= 0)
  {
    shutterMove(true);
    motorStart();

    printSeq = PSEQ_RUNNING;
    printStatus("print_sequence_running");

    if (printDonePending)
    {
      printSeq = PSEQ_WAIT_END;
      printSeqAt = now + PRINT_END_DELAY_MS;
      printDonePending = false;
    }
  }
  else if (printSeq == PSEQ_WAIT_END && (long)(now - printSeqAt) >= 0)
  {
    printSeqEnd("print_sequence_complete");
  }
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
  validSpO2Hits = 0;
  lastFingerPresent = false;
  maxSpO2ExtendUsed = false;
  maxCollectionMs = (unsigned long)MAX_COLLECTION_SECONDS * 1000UL;

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

  static int hits = 0;

  if (isnan(objectC) || isnan(ambientC))
  {
    hits = 0;
    return false;
  }

  if ((objectC - ambientC) > PRESENCE_DELTA_C)
  {
    if (++hits >= PRESENCE_CONFIRM_COUNT)
    {
      hits = 0;
      return true;
    }
  }
  else
  {
    hits = 0;
  }

  return false;
}

// Compensate for reduced reading at distance (wider FOV mixes in ambient)
float applyDistanceGain(float objectC, float ambientC)
{
  return ambientC + (objectC - ambientC) * TEMP_DISTANCE_GAIN;
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

  bpmSum += (float)bpm;
  bpmWeightSum += 1.0f;
  bpmCount++;
}

void accumulateSpO2(int32_t spo2)
{
  if (spo2 > 0 && spo2 >= SPO2_MIN && spo2 <= SPO2_MAX)
  {
    spo2Sum += spo2;
    spo2Count++;
    validSpO2Hits++;
  }
}

void accumulateTempSample()
{
  if (!sessionTEMP || !tempSensorOK)
  {
    return;
  }

  // Still inside the 2 s settle delay after detection
  if (millis() < tempCollectionStart)
  {
    return;
  }

  float objectC = readMLXTemperature(0x07);
  float ambientC = readMLXTemperature(0x06);

  if (isnan(objectC) || isnan(ambientC))
  {
    return;
  }

  if (objectC < TEMP_RAW_MIN_C)
  {
    return;
  }

  objectC = applyDistanceGain(objectC, ambientC);

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

  const int totalSeconds = (int)(maxCollectionMs / 1000UL);
  int remaining = totalSeconds - secondsElapsed;
  if (remaining < 0)
  {
    remaining = 0;
  }

  response["status"] = "recording";
  response["sensor"] = "max30102";
  response["elapsed"] = secondsElapsed;
  response["remaining"] = remaining;
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
  {
    response["spo2"] = spo2Sum / spo2Count;
    response["spo2_quality"] = "ok";
  }
  else if (sessionMAX)
  {
    response["spo2"] = nullptr;
    response["spo2_quality"] = "missing";
  }

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

  if (sessionMAX)
  {
    Serial.printf(
      "[MAX] complete bpmCount=%d spo2Count=%d validSpO2Hits=%d finger=%d extend=%d\n",
      bpmCount,
      spo2Count,
      validSpO2Hits,
      lastFingerPresent ? 1 : 0,
      maxSpO2ExtendUsed ? 1 : 0
    );
  }

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
// CHARGER MONITOR (INA226)
// =====================================================

enum ChargerState
{
  CH_OFF,        // charger relay is OFF
  CH_WAITING,    // relay ON, no phone connected
  CH_CHARGING    // relay ON, phone connected and charging
};

ChargerState chargerState = CH_OFF;

bool inaOK = false;
uint8_t inaFailCount = 0;

float chargerVolts = 0.0f;
float chargerMA = 0.0f;
float chargerW = 0.0f;
float chargerPeakW = 0.0f;

int chargerPlugCount = 0;
int chargerUnplugCount = 0;
int chargerLowStreak = 0;

unsigned long lastChargerPoll = 0;
unsigned long lastInaInit = 0;
unsigned long lastChargerDebug = 0;
unsigned long chargerRelayOnMs = 0;
unsigned long chargerPlugMs = 0;

const char* chargerLastResult = "none";

bool ina226Read16(uint8_t reg, uint16_t &value)
{
  Wire.beginTransmission(INA226_ADDR);
  Wire.write(reg);

  if (Wire.endTransmission(false) != 0)
  {
    return false;
  }

  if (Wire.requestFrom((uint8_t)INA226_ADDR, (uint8_t)2) != 2)
  {
    return false;
  }

  uint8_t hi = Wire.read();
  uint8_t lo = Wire.read();

  value = ((uint16_t)hi << 8) | lo;

  return true;
}

bool ina226Write16(uint8_t reg, uint16_t value)
{
  Wire.beginTransmission(INA226_ADDR);
  Wire.write(reg);
  Wire.write((uint8_t)(value >> 8));
  Wire.write((uint8_t)(value & 0xFF));

  return (Wire.endTransmission() == 0);
}

bool initINA226()
{
  uint16_t id = 0;

  // 0x5449 = "TI". Confirms a real INA226 is answering.
  if (!ina226Read16(INA226_REG_MANUF_ID, id) || id != 0x5449)
  {
    return false;
  }

  return ina226Write16(INA226_REG_CONFIG, INA226_CONFIG_VALUE);
}

bool readCharger(float &volts, float &mA, float &watts)
{
  uint16_t rawBus = 0;
  uint16_t rawShunt = 0;

  if (!ina226Read16(INA226_REG_BUS, rawBus)) return false;
  if (!ina226Read16(INA226_REG_SHUNT, rawShunt)) return false;

  // Bus voltage: 1.25 mV per bit
  volts = rawBus * 0.00125f;

  // Shunt voltage: 2.5 uV per bit -> mA = mV / ohms
  // fabsf() so the reading is positive whichever way the INA226
  // IN+ / IN- wires are connected.
  mA = fabsf((float)(int16_t)rawShunt * 0.0025f / INA226_SHUNT_OHMS);

  watts = volts * mA / 1000.0f;

  return true;
}

const char* chargerStateName()
{
  if (chargerState == CH_CHARGING) return "charging";
  if (chargerState == CH_WAITING) return "waiting_for_phone";
  return "relay_off";
}

void resetChargerCounters()
{
  chargerPlugCount = 0;
  chargerUnplugCount = 0;
  chargerLowStreak = 0;
  chargerPeakW = 0.0f;
}

// Events: plugged_in, plugged_out, charge_complete, charge_timeout,
//         ina226_error, ina226_ready, debug
void sendChargerEvent(const char* event)
{
  JsonDocument response;

  response["charger"] = event;
  response["relay_state"] = getRelayState(CHARGER_RELAY) ? "on" : "off";
  response["volts"] = roundf(chargerVolts * 100.0f) / 100.0f;
  response["current_ma"] = roundf(chargerMA);
  response["power_w"] = roundf(chargerW * 100.0f) / 100.0f;
  response["ts"] = millis();

  serializeJson(response, Serial);
  Serial.println();
}

// Answer to {"command":"charger"} / "CHARGER"
void sendChargerSnapshot()
{
  // Do not touch the I2C bus while the MAX30102 is recording.
  if (inaOK && !sessionMAX)
  {
    float v, mA, w;

    if (readCharger(v, mA, w))
    {
      chargerVolts = v;
      chargerMA = mA;
      chargerW = w;
    }
  }

  JsonDocument response;

  response["charger"] = "status";
  response["ina226"] = inaOK;
  response["state"] = chargerStateName();
  response["plugged"] = (chargerState == CH_CHARGING);
  response["last_result"] = chargerLastResult;
  response["relay_state"] = getRelayState(CHARGER_RELAY) ? "on" : "off";
  response["volts"] = roundf(chargerVolts * 100.0f) / 100.0f;
  response["current_ma"] = roundf(chargerMA);
  response["power_w"] = roundf(chargerW * 100.0f) / 100.0f;
  response["ts"] = millis();

  serializeJson(response, Serial);
  Serial.println();
}

// Switch the charger relay OFF and tell the host why.
void chargerStop(const char* event)
{
  setRelay(CHARGER_RELAY, false);

  chargerLastResult = event;
  chargerState = CH_OFF;

  sendChargerEvent(event);

  resetChargerCounters();
}

void pollCharger()
{
  unsigned long now = millis();

  if (now - lastChargerPoll < CHARGER_POLL_MS)
  {
    return;
  }

  // Polling was paused for a while: restart the debounce counters.
  if (now - lastChargerPoll > CHARGER_GAP_MS)
  {
    chargerPlugCount = 0;
    chargerUnplugCount = 0;
  }

  lastChargerPoll = now;

  // INA226 missing / lost: retry now and then.
  if (!inaOK)
  {
    if (now - lastInaInit >= CHARGER_REINIT_MS)
    {
      lastInaInit = now;
      inaOK = initINA226();

      if (inaOK)
      {
        inaFailCount = 0;
        sendChargerEvent("ina226_ready");
      }
    }

    return;
  }

  // Relay OFF: the charging module is unpowered, nothing to watch.
  if (!getRelayState(CHARGER_RELAY))
  {
    if (chargerState != CH_OFF)
    {
      chargerState = CH_OFF;
      resetChargerCounters();
    }

    return;
  }

  // Relay just turned ON
  if (chargerState == CH_OFF)
  {
    chargerState = CH_WAITING;
    resetChargerCounters();
    chargerRelayOnMs = now;
  }

  if (now - chargerRelayOnMs < CHARGER_SETTLE_MS)
  {
    return;
  }

  float v = 0.0f;
  float mA = 0.0f;
  float w = 0.0f;

  if (!readCharger(v, mA, w))
  {
    if (++inaFailCount >= 5)
    {
      inaOK = false;
      lastInaInit = now;
      sendChargerEvent("ina226_error");
    }

    return;
  }

  inaFailCount = 0;

  chargerVolts = v;
  chargerMA = mA;
  chargerW = w;

  // The value the plug in / out / full logic works on (mA or watts)
  float level = CHARGER_USE_CURRENT ? mA : w;

  if (CHARGER_DEBUG_STREAM && (now - lastChargerDebug >= 2000))
  {
    lastChargerDebug = now;
    sendChargerEvent("debug");
  }

  // ---------- no phone yet: wait for plug in ----------
  if (chargerState == CH_WAITING)
  {
    if (level >= CH_PLUG_ON)
    {
      if (++chargerPlugCount >= CHARGER_PLUG_CONFIRM)
      {
        chargerState = CH_CHARGING;
        chargerPlugMs = now;

        chargerPlugCount = 0;
        chargerUnplugCount = 0;
        chargerLowStreak = 0;
        chargerPeakW = level;

        chargerLastResult = "plugged_in";
        sendChargerEvent("plugged_in");
      }
    }
    else
    {
      chargerPlugCount = 0;
    }

    return;
  }

  // ---------- phone connected: watch for unplug / full ----------
  if (chargerState == CH_CHARGING)
  {
    if (level > chargerPeakW)
    {
      chargerPeakW = level;
    }

    if (level >= CH_FULL)
    {
      // Still charging properly
      chargerLowStreak = 0;
      chargerUnplugCount = 0;
    }
    else
    {
      // Sudden drop to ~0 right after real charging = cable pulled
      if (
        level < CH_PLUG_OFF &&
        chargerLowStreak < CHARGER_ABRUPT_SAMPLES
      )
      {
        chargerUnplugCount++;
      }
      else
      {
        chargerUnplugCount = 0;
      }

      chargerLowStreak++;
    }

    if (chargerUnplugCount >= CHARGER_UNPLUG_CONFIRM)
    {
      // Phone pulled out: switch the charger relay OFF
      chargerStop("plugged_out");
      return;
    }

    // Power stayed low long enough after a real charge: phone is full
    if (
      chargerLowStreak >= CHARGER_FULL_HOLD_SAMPLES &&
      chargerPeakW >= CH_FULL
    )
    {
      chargerStop("charge_complete");
      return;
    }

    // Safety limit
    if (now - chargerPlugMs >= (unsigned long)CHARGER_MAX_MINUTES * 60000UL)
    {
      chargerStop("charge_timeout");
      return;
    }
  }
}


// Prints whether the INA226 answers on the I2C bus:
// {"charger":"ina226_connected",...} or {"charger":"ina226_not_connected",...}
void reportINA226()
{
  Wire.beginTransmission(INA226_ADDR);
  uint8_t i2cErr = Wire.endTransmission();

  JsonDocument response;

  response["charger"] = (i2cErr == 0 && inaOK)
    ? "ina226_connected"
    : "ina226_not_connected";

  response["addr"] = "0x40";
  response["i2c_ack"] = (i2cErr == 0);
  response["i2c_err"] = i2cErr;
  response["init_ok"] = inaOK;
  response["ts"] = millis();

  serializeJson(response, Serial);
  Serial.println();
}

// Lists every I2C address that answers, e.g. ["0x40","0x57","0x5A"]
// Expected: 0x40 = INA226, 0x57 = MAX30102, 0x5A = MLX90614
void i2cScanReport()
{
  JsonDocument response;

  JsonArray found = response["i2c_found"].to<JsonArray>();

  for (uint8_t addr = 1; addr < 127; addr++)
  {
    Wire.beginTransmission(addr);

    if (Wire.endTransmission() == 0)
    {
      char buf[8];
      snprintf(buf, sizeof(buf), "0x%02X", addr);
      found.add(String(buf));
    }

    if (watchdogRunning)
    {
      esp_task_wdt_reset();
    }
  }

  response["ts"] = millis();

  serializeJson(response, Serial);
  Serial.println();
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

  if (!command["print"].isNull())
  {
    processPrintCommand(command);
    return;
  }

  if (!command["motor"].isNull() || !command["motor_speed"].isNull())
  {
    processMotorCommand(command);
    return;
  }

  if (
    !command["shutter"].isNull() ||
    !command["shutter_angle"].isNull() ||
    !command["shutter_us"].isNull() ||
    !command["shutter_set"].isNull()
  )
  {
    processShutterCommand(command);
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

  if (strcmp(cmd, "charger") == 0)
  {
    sendChargerSnapshot();
    return;
  }

  if (strcmp(cmd, "scan") == 0)
  {
    reportINA226();
    i2cScanReport();
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
  else if (command == "SHUTTER OPEN")
  {
    shutterMove(true);
  }
  else if (command == "SHUTTER CLOSE")
  {
    shutterMove(false);
  }
  else if (command == "CHARGER")
  {
    sendChargerSnapshot();
  }
  else if (command == "SCAN")
  {
    reportINA226();
    i2cScanReport();
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

// Unused GPIOs near the relay pin. Held LOW from boot so
// they cannot float or couple into the relay input.
static const uint8_t PARKED_PINS[] = { 25 };

void parkUnusedPins()
{
  for (uint8_t i = 0; i < sizeof(PARKED_PINS); i++)
  {
    pinMode(PARKED_PINS[i], OUTPUT);
    digitalWrite(PARKED_PINS[i], LOW);
  }
}

void setup()
{
  // Relay OFF and neighbouring pins parked before anything else, so
  // the charger relay is never left on by a floating pin at boot.
  parkUnusedPins();
  allRelaysOff();

  // Hold the servo signal LOW from the very first instruction so the
  // line is never left floating (a floating signal makes a continuous
  // servo creep or spin). Before setup() runs the pin is still
  // high-Z, so also fit a 10k resistor from the signal wire to GND.
  pinMode(SHUTTER_PIN, OUTPUT);
  digitalWrite(SHUTTER_PIN, LOW);

  // ESP32Servo: reserve LEDC timer 0 for the servo so it does not
  // collide with the roller motor's 20 kHz PWM. Must run before the
  // servo is first attached (shutterBegin() may do that).
  ESP32PWM::allocateTimer(0);

  Serial.begin(SERIAL_BAUD);

  delay(1000);

  allRelaysOff();

  shutterBegin();

  motorBegin();

  startI2C();

  maxSensorOK = initializeMAX30102();

  tempSensorOK = checkMLX90614();

  inaOK = initINA226();

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
  startup["ina226"] = inaOK;
  startup["relay1"] = getRelayState(1);
  startup["relay2"] = getRelayState(2);
  startup["shutter"] = shutterStateName();
  startup["motor"] = motorRunning ? "on" : "off";

  serializeJson(startup, Serial);
  Serial.println();

  // Show clearly whether the INA226 is connected, and which
  // I2C devices the ESP32 can see at all.
  reportINA226();
  i2cScanReport();

  startWatchdog();
}


// =====================================================
// MAIN LOOP
// =====================================================

void loop()
{
  esp_task_wdt_reset();

  processCommands();

  shutterUpdate();

  motorUpdate();

  printSeqUpdate();

  if (
    currentState != STATE_IDLE &&
    millis() - sessionStartMs >
      (unsigned long)SESSION_MAX_SECONDS * 1000UL
  )
  {
    abortSession("session_timeout");
    return;
  }

  // Charger plug in / plug out / full detection. Skipped while the
  // MAX30102 is recording so the extra I2C traffic cannot disturb it.
  if (!sessionMAX)
  {
    pollCharger();
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
        tempCollectionStart = millis() + TEMP_SETTLE_MS;
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

      lastFingerPresent = true;
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
            tempCollectionStart = millis() + TEMP_SETTLE_MS;

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
      int maxTotalSeconds = (int)(maxCollectionMs / 1000UL);

      if (
        maxSeconds != lastMaxSecondReported &&
        maxSeconds <= maxTotalSeconds
      )
      {
        lastMaxSecondReported = maxSeconds;

        printMAXCountdown(maxSeconds);
      }
    }

    if (sessionTEMP && tempStarted && millis() >= tempCollectionStart)
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
      (millis() - collectionStart >= maxCollectionMs);

    // Finger still on but no SpO2 yet: extend once before completing.
    if (
      sessionMAX &&
      maxDone &&
      spo2Count == 0 &&
      lastFingerPresent &&
      !maxSpO2ExtendUsed
    )
    {
      maxSpO2ExtendUsed = true;
      maxCollectionMs +=
        (unsigned long)MAX_SPO2_EXTEND_SECONDS * 1000UL;
      maxDone = false;
      printStatus("spo2_extending");
      Serial.printf(
        "[MAX] spo2 extend +%ds bpmCount=%d\n",
        MAX_SPO2_EXTEND_SECONDS,
        bpmCount
      );
    }

    bool tempDone;

    if (!sessionTEMP)
    {
      tempDone = true;
    }
    else if (tempStarted)
    {
      tempDone =
        (
          millis() >= tempCollectionStart &&
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

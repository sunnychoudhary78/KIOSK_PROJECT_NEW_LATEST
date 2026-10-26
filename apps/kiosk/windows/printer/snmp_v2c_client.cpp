#include "snmp_v2c_client.h"

#include "snmp_ber.h"

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <winsock2.h>
#include <ws2tcpip.h>

#include <chrono>
#include <cstring>
#include <sstream>

#pragma comment(lib, "ws2_32.lib")

namespace skp_printer {
namespace {

bool EnsureWinsock() {
  static bool ready = false;
  static bool ok = false;
  if (ready) {
    return ok;
  }
  ready = true;
  WSADATA data;
  ok = WSAStartup(MAKEWORD(2, 2), &data) == 0;
  return ok;
}

void AppendLength(std::vector<uint8_t>& out, size_t length) {
  if (length < 0x80) {
    out.push_back(static_cast<uint8_t>(length));
    return;
  }
  if (length <= 0xFF) {
    out.push_back(0x81);
    out.push_back(static_cast<uint8_t>(length));
    return;
  }
  out.push_back(0x82);
  out.push_back(static_cast<uint8_t>((length >> 8) & 0xFF));
  out.push_back(static_cast<uint8_t>(length & 0xFF));
}

void AppendInteger(std::vector<uint8_t>& out, int64_t value) {
  std::vector<uint8_t> bytes;
  uint64_t u = static_cast<uint64_t>(value);
  if (value < 0) {
    // Two's complement minimal encoding is enough for our request-ids (>=0).
    u = static_cast<uint64_t>(value);
  }
  do {
    bytes.insert(bytes.begin(), static_cast<uint8_t>(u & 0xFF));
    u >>= 8;
  } while (u != 0);
  if (!bytes.empty() && (bytes[0] & 0x80)) {
    bytes.insert(bytes.begin(), 0x00);
  }
  if (bytes.empty()) {
    bytes.push_back(0);
  }
  out.push_back(0x02);
  AppendLength(out, bytes.size());
  out.insert(out.end(), bytes.begin(), bytes.end());
}

void AppendOctetString(std::vector<uint8_t>& out, const std::string& value) {
  out.push_back(0x04);
  AppendLength(out, value.size());
  out.insert(out.end(), value.begin(), value.end());
}

void AppendNull(std::vector<uint8_t>& out) {
  out.push_back(0x05);
  out.push_back(0x00);
}

void AppendOid(std::vector<uint8_t>& out, const SnmpOid& oid) {
  if (oid.arcs.size() < 2) {
    return;
  }
  std::vector<uint8_t> body;
  body.push_back(static_cast<uint8_t>(oid.arcs[0] * 40 + oid.arcs[1]));
  for (size_t i = 2; i < oid.arcs.size(); ++i) {
    uint32_t v = oid.arcs[i];
    std::vector<uint8_t> enc;
    enc.push_back(static_cast<uint8_t>(v & 0x7F));
    v >>= 7;
    while (v != 0) {
      enc.insert(enc.begin(), static_cast<uint8_t>((v & 0x7F) | 0x80));
      v >>= 7;
    }
    body.insert(body.end(), enc.begin(), enc.end());
  }
  out.push_back(0x06);
  AppendLength(out, body.size());
  out.insert(out.end(), body.begin(), body.end());
}

void AppendSequence(std::vector<uint8_t>& out, uint8_t tag, const std::vector<uint8_t>& body) {
  out.push_back(tag);
  AppendLength(out, body.size());
  out.insert(out.end(), body.begin(), body.end());
}

size_t ReadLength(const std::vector<uint8_t>& buf, size_t& i) {
  if (i >= buf.size()) {
    return 0;
  }
  uint8_t first = buf[i++];
  if ((first & 0x80) == 0) {
    return first;
  }
  size_t n = first & 0x7F;
  size_t length = 0;
  for (size_t k = 0; k < n && i < buf.size(); ++k) {
    length = (length << 8) | buf[i++];
  }
  return length;
}

bool SkipTlv(const std::vector<uint8_t>& buf, size_t& i) {
  if (i >= buf.size()) {
    return false;
  }
  ++i;  // tag
  size_t len = ReadLength(buf, i);
  if (i + len > buf.size()) {
    return false;
  }
  i += len;
  return true;
}

std::optional<int64_t> ParseIntegerAt(const std::vector<uint8_t>& buf, size_t& i) {
  if (i >= buf.size() || !IsSnmpIntegerTag(buf[i])) {
    return std::nullopt;
  }
  const uint8_t tag = buf[i++];
  size_t len = ReadLength(buf, i);
  if (len == 0 || i + len > buf.size()) {
    return std::nullopt;
  }
  auto value = DecodeSnmpInteger(tag, &buf[i], len);
  i += len;
  return value;
}

std::optional<std::string> ParseOctetAt(const std::vector<uint8_t>& buf, size_t& i) {
  if (i >= buf.size() || buf[i] != 0x04) {
    return std::nullopt;
  }
  ++i;
  size_t len = ReadLength(buf, i);
  if (i + len > buf.size()) {
    return std::nullopt;
  }
  std::string s(reinterpret_cast<const char*>(&buf[i]), len);
  i += len;
  return s;
}

}  // namespace

std::optional<SnmpOid> SnmpOid::Parse(const std::string& dotted) {
  SnmpOid oid;
  std::stringstream ss(dotted);
  std::string part;
  while (std::getline(ss, part, '.')) {
    if (part.empty()) {
      continue;
    }
    try {
      oid.arcs.push_back(static_cast<uint32_t>(std::stoul(part)));
    } catch (...) {
      return std::nullopt;
    }
  }
  if (oid.arcs.size() < 2) {
    return std::nullopt;
  }
  return oid;
}

SnmpV2cClient::SnmpV2cClient(std::string host, std::string community, int timeout_ms)
    : host_(std::move(host)), community_(std::move(community)), timeout_ms_(timeout_ms) {}

std::vector<uint8_t> SnmpV2cClient::BuildGetRequest(const SnmpOid& oid, int32_t request_id) const {
  std::vector<uint8_t> varbind_inner;
  AppendOid(varbind_inner, oid);
  AppendNull(varbind_inner);
  std::vector<uint8_t> varbind;
  AppendSequence(varbind, 0x30, varbind_inner);
  std::vector<uint8_t> varbind_list;
  AppendSequence(varbind_list, 0x30, varbind);

  std::vector<uint8_t> pdu_inner;
  AppendInteger(pdu_inner, request_id);
  AppendInteger(pdu_inner, 0);  // error-status
  AppendInteger(pdu_inner, 0);  // error-index
  pdu_inner.insert(pdu_inner.end(), varbind_list.begin(), varbind_list.end());
  std::vector<uint8_t> pdu;
  AppendSequence(pdu, 0xA0, pdu_inner);  // GetRequest

  std::vector<uint8_t> message_inner;
  AppendInteger(message_inner, 1);  // SNMPv2c
  AppendOctetString(message_inner, community_);
  message_inner.insert(message_inner.end(), pdu.begin(), pdu.end());
  std::vector<uint8_t> message;
  AppendSequence(message, 0x30, message_inner);
  return message;
}

std::optional<std::vector<uint8_t>> SnmpV2cClient::TransactOnce(
    const std::vector<uint8_t>& request) const {
  SOCKET sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
  if (sock == INVALID_SOCKET) {
    return std::nullopt;
  }

  DWORD timeout = static_cast<DWORD>(timeout_ms_ > 0 ? timeout_ms_ : 3000);
  setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, reinterpret_cast<const char*>(&timeout),
             sizeof(timeout));
  setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, reinterpret_cast<const char*>(&timeout),
             sizeof(timeout));

  sockaddr_in addr{};
  addr.sin_family = AF_INET;
  addr.sin_port = htons(161);
  if (InetPtonA(AF_INET, host_.c_str(), &addr.sin_addr) != 1) {
    closesocket(sock);
    return std::nullopt;
  }

  int sent = sendto(sock, reinterpret_cast<const char*>(request.data()),
                    static_cast<int>(request.size()), 0, reinterpret_cast<sockaddr*>(&addr),
                    sizeof(addr));
  if (sent < 0) {
    closesocket(sock);
    return std::nullopt;
  }

  std::vector<uint8_t> response(2048);
  int received =
      recvfrom(sock, reinterpret_cast<char*>(response.data()), static_cast<int>(response.size()),
               0, nullptr, nullptr);
  closesocket(sock);
  if (received <= 0) {
    return std::nullopt;
  }
  response.resize(static_cast<size_t>(received));
  return response;
}

std::optional<std::vector<uint8_t>> SnmpV2cClient::Transact(
    const std::vector<uint8_t>& request) const {
  if (!EnsureWinsock()) {
    return std::nullopt;
  }
  // Match the working Python monitor: timeout per try, one retry.
  for (int attempt = 0; attempt < 2; ++attempt) {
    auto response = TransactOnce(request);
    if (response) {
      return response;
    }
  }
  return std::nullopt;
}

std::optional<int64_t> SnmpV2cClient::GetInteger(const SnmpOid& oid) const {
  auto request_id =
      static_cast<int32_t>(std::chrono::steady_clock::now().time_since_epoch().count() & 0x7FFFFFFF);
  auto request = BuildGetRequest(oid, request_id);
  auto response = Transact(request);
  if (!response) {
    return std::nullopt;
  }
  const auto& buf = *response;
  // Locate GetResponse PDU (0xA2) and read the first varbind value after
  // request-id / error-status / error-index.
  for (size_t i = 0; i + 1 < buf.size(); ++i) {
    if (buf[i] != 0xA2) {
      continue;
    }
    size_t j = i + 1;
    size_t pdu_len = ReadLength(buf, j);
    size_t pdu_end = j + pdu_len;
    if (pdu_end > buf.size()) {
      return std::nullopt;
    }
    if (!ParseIntegerAt(buf, j) || !ParseIntegerAt(buf, j) || !ParseIntegerAt(buf, j)) {
      return std::nullopt;
    }
    if (j >= pdu_end || buf[j] != 0x30) {
      return std::nullopt;
    }
    ++j;
    size_t list_len = ReadLength(buf, j);
    size_t list_end = j + list_len;
    if (list_end > pdu_end || j >= list_end || buf[j] != 0x30) {
      return std::nullopt;
    }
    ++j;
    size_t vb_len = ReadLength(buf, j);
    size_t vb_end = j + vb_len;
    if (vb_end > list_end) {
      return std::nullopt;
    }
    if (!SkipTlv(buf, j) || j >= vb_end) {
      return std::nullopt;
    }
    uint8_t tag = buf[j];
    if (tag == 0x02 || tag == 0x41 || tag == 0x42 || tag == 0x43) {
      return ParseIntegerAt(buf, j);
    }
    return std::nullopt;
  }
  return std::nullopt;
}

std::optional<std::string> SnmpV2cClient::GetOctetString(const SnmpOid& oid) const {
  auto request_id =
      static_cast<int32_t>(std::chrono::steady_clock::now().time_since_epoch().count() & 0x7FFFFFFF);
  auto request = BuildGetRequest(oid, request_id);
  auto response = Transact(request);
  if (!response) {
    return std::nullopt;
  }
  const auto& buf = *response;
  for (size_t i = 0; i + 1 < buf.size(); ++i) {
    if (buf[i] != 0xA2) {
      continue;
    }
    size_t j = i + 1;
    size_t pdu_len = ReadLength(buf, j);
    size_t pdu_end = j + pdu_len;
    if (pdu_end > buf.size()) {
      return std::nullopt;
    }
    if (!ParseIntegerAt(buf, j) || !ParseIntegerAt(buf, j) || !ParseIntegerAt(buf, j)) {
      return std::nullopt;
    }
    if (j >= pdu_end || buf[j] != 0x30) {
      return std::nullopt;
    }
    ++j;
    ReadLength(buf, j);
    if (j >= buf.size() || buf[j] != 0x30) {
      return std::nullopt;
    }
    ++j;
    ReadLength(buf, j);
    if (!SkipTlv(buf, j) || j >= buf.size()) {
      return std::nullopt;
    }
    return ParseOctetAt(buf, j);
  }
  return std::nullopt;
}

}  // namespace skp_printer

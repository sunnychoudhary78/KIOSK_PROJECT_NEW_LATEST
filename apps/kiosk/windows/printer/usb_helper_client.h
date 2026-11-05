#ifndef SKP_PRINTER_USB_HELPER_CLIENT_H_
#define SKP_PRINTER_USB_HELPER_CLIENT_H_

#include <string>

namespace skp_printer {

// One JSON object from the Brother USB HTTP helper. Never throws.
// error is helper_missing, password_missing, auth_failed, bridge_unreachable,
// busy, or usb_timeout when the read fails.
// [password] is forwarded to the helper and must not be logged.
std::string RequestUsbSnapshot(const std::string& scope, const std::string& password = {});

}  // namespace skp_printer

#endif  // SKP_PRINTER_USB_HELPER_CLIENT_H_

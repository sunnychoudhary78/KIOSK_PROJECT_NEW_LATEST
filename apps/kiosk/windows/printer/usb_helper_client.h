#ifndef SKP_PRINTER_USB_HELPER_CLIENT_H_
#define SKP_PRINTER_USB_HELPER_CLIENT_H_

#include <string>

namespace skp_printer {

// One JSON object from the x86 Brother USB helper. Never throws.
// error is helper_missing, sdk_missing, busy, or usb_timeout when the read fails.
std::string RequestUsbSnapshot(const std::string& scope);

}  // namespace skp_printer

#endif  // SKP_PRINTER_USB_HELPER_CLIENT_H_

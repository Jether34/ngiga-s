#pragma once
#include <string>

namespace stockroom {
bool sendEmail(const std::string &recipient, const std::string &subject,
               const std::string &message, const std::string &attachmentName = "",
               const std::string &attachment = "", const std::string &htmlBody = "");
}

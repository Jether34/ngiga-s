#include "mailer.hpp"
#include <curl/curl.h>
#include <cstdlib>
#include <regex>

namespace stockroom {
bool sendEmail(const std::string &recipient, const std::string &subject,
               const std::string &message, const std::string &attachmentName,
               const std::string &attachment, const std::string &htmlBody) {
    const char *username = std::getenv("SMTP_USERNAME");
    const char *password = std::getenv("SMTP_PASSWORD");
    if (!username || !password || !*username || !*password ||
        !std::regex_match(recipient, std::regex(R"([^\s@\r\n]+@[^\s@\r\n]+\.[^\s@\r\n]+)"))) return false;
    CURL *curl = curl_easy_init();
    if (!curl) return false;
    curl_slist *recipients = nullptr;
    curl_slist *headers = nullptr;
    curl_mime *mime = curl_mime_init(curl);
    recipients = curl_slist_append(recipients, recipient.c_str());
    const std::string from = "From: ENcoRE <" + std::string(username) + ">";
    const std::string to = "To: <" + recipient + ">";
    const std::string safeSubject = std::regex_replace(subject, std::regex(R"([\r\n])"), " ");
    headers = curl_slist_append(headers, from.c_str());
    headers = curl_slist_append(headers, to.c_str());
    headers = curl_slist_append(headers, ("Subject: " + safeSubject).c_str());
    curl_mimepart *part;
    if (htmlBody.empty()) {
        part = curl_mime_addpart(mime);
        curl_mime_data(part, message.c_str(), CURL_ZERO_TERMINATED);
        curl_mime_type(part, "text/plain; charset=utf-8");
    } else {
        curl_mime *alternatives = curl_mime_init(curl);
        part = curl_mime_addpart(alternatives);
        curl_mime_data(part, message.c_str(), CURL_ZERO_TERMINATED);
        curl_mime_type(part, "text/plain; charset=utf-8");
        part = curl_mime_addpart(alternatives);
        curl_mime_data(part, htmlBody.c_str(), CURL_ZERO_TERMINATED);
        curl_mime_type(part, "text/html; charset=utf-8");
        part = curl_mime_addpart(mime);
        curl_mime_subparts(part, alternatives);
        curl_mime_type(part, "multipart/alternative");
    }
    if (!attachmentName.empty()) {
        part = curl_mime_addpart(mime);
        curl_mime_data(part, attachment.c_str(), attachment.size());
        curl_mime_type(part, attachmentName.size() >= 5 &&
            attachmentName.substr(attachmentName.size() - 5) == ".html"
                ? "text/html; charset=utf-8" : "text/plain; charset=utf-8");
        curl_mime_filename(part, attachmentName.c_str());
    }
    curl_easy_setopt(curl, CURLOPT_URL, "smtps://smtp.gmail.com:465");
    curl_easy_setopt(curl, CURLOPT_USERNAME, username);
    curl_easy_setopt(curl, CURLOPT_PASSWORD, password);
    curl_easy_setopt(curl, CURLOPT_MAIL_FROM, username);
    curl_easy_setopt(curl, CURLOPT_MAIL_RCPT, recipients);
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl, CURLOPT_MIMEPOST, mime);
    curl_easy_setopt(curl, CURLOPT_USE_SSL, CURLUSESSL_ALL);
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 1L);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 20L);
    const auto result = curl_easy_perform(curl);
    curl_mime_free(mime);
    curl_slist_free_all(headers);
    curl_slist_free_all(recipients);
    curl_easy_cleanup(curl);
    return result == CURLE_OK;
}
}

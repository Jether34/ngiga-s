import 'package:flutter/material.dart';

import 'app_palette.dart';

const _privacySections = <(String, String)>[
  (
    'Information collected',
    'E-QUIP stores the details you provide when creating an account: your name, email, phone number, year level, program, and home address. It also stores your generated student or user ID, login and account state, scanned item identifiers, loan and return dates, and receipt history.',
  ),
  (
    'Camera and barcode scans',
    'The camera is used to read an equipment barcode or QR code. The decoded item code is sent to E-QUIP to look up equipment and record a confirmed loan or return. Camera images and video are not uploaded as part of the scan request.',
  ),
  (
    'How information is used',
    'Information is used to authenticate your account, manage equipment loans and returns, show receipts and loan history, and help authorized campus staff administer inventory and resolve account or equipment issues.',
  ),
  (
    'Who can access it',
    'Authorized inventory administrators can see borrower identity and the account and transaction details needed to manage equipment. Information may also be processed by service providers that operate or maintain the app and its database.',
  ),
  (
    'Storage and retention',
    'Account and transaction records are stored in the E-QUIP database. Records are kept while needed to operate the account and meet the institution’s inventory and record keeping requirements. Ask your campus administrator about the institution’s retention period.',
  ),
  (
    'Your choices',
    'You may ask the campus administrator to review or correct your account details, or to explain the institution’s deletion and retention process. Some loan and inventory records may need to remain available for institutional records.',
  ),
  (
    'Security and contact',
    'E-QUIP uses password hashing and authenticated access controls. No online system can guarantee absolute security. For privacy questions, contact your laboratory or campus administrator through your institution’s usual support channel.',
  ),
];

const _termsSections = <(String, String)>[
  (
    'Your account',
    'Provide accurate account information and keep your password private. Public sign up creates a student account. E-QUIP assigns your student or user ID after registration.',
  ),
  (
    'Borrowing equipment',
    'Choose a due date and time, scan the intended item, review the item and account details, then confirm the loan. A loan is created only after the server accepts the request. Borrowing and returning require an internet connection.',
  ),
  (
    'Care and return',
    'Use borrowed equipment for its intended campus purpose, take reasonable care of it, and return the same physical item by the due date using the authorized return workflow. Report loss, damage, or a scan problem to the inventory administrator promptly.',
  ),
  (
    'Accountability',
    'E-QUIP records the borrower, physical item, barcode, due time, and return status so the borrower and authorized administrators can view the receipt and transaction history. Do not lend an issued item to another person or alter its barcode.',
  ),
  (
    'Acceptable use',
    'Do not use E-QUIP to access another person’s account, falsify inventory records, or bypass equipment controls. The institution may restrict borrowing access when required to protect equipment or resolve an overdue or disputed loan.',
  ),
  (
    'Availability and changes',
    'Borrowing and returns need an active connection and depend on the campus service being available. The institution may update these terms and will publish the current version in the app.',
  ),
  (
    'Questions',
    'For help with an account, loan, return, or these terms, contact your laboratory or campus inventory administrator through your institution’s usual support channel.',
  ),
];

Future<void> showAuthPolicy(BuildContext context, {required bool privacy}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .82,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppPalette.line,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 21),
                Text(
                  privacy ? 'Privacy Policy' : 'Terms and Conditions',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.ink,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      for (final (title, body)
                          in privacy ? _privacySections : _termsSections)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 19),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppPalette.ink,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                body,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  height: 1.48,
                                  color: AppPalette.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

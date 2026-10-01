import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../widgets/top_bar.dart';

class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({super.key});

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  final _webViewCtrl = WebViewController()
    ..setBackgroundColor(Colors.white)
    ..enableZoom(true);

  @override
  void initState() {
    super.initState();

    _webViewCtrl.loadHtmlString('''
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0, minimum-scale=1.0, maximum-scale=5.0, user-scalable=yes">
      <title>MBS SAP Privacy Policy</title>
      <style>
        * { box-sizing: border-box; }
        html { -webkit-text-size-adjust: 100%; text-size-adjust: 100%; }
        body {
          margin: 0;
          padding: 18px 18px 48px;
          background: #ffffff;
          color: #1f2937;
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
          font-size: 15px;
          line-height: 1.7;
          overflow-wrap: break-word;
          -webkit-font-smoothing: antialiased;
        }
        h1 {
          margin: 0 0 14px;
          color: #1565c0;
          font-size: 21px;
          line-height: 1.35;
          font-weight: 700;
          letter-spacing: .2px;
        }
        h2 {
          margin: 30px 0 12px;
          padding-top: 16px;
          border-top: 1px solid #eceff1;
          color: #1f2937;
          font-size: 17px;
          line-height: 1.4;
          font-weight: 600;
        }
        p { margin: 0 0 14px; }
        ul { margin: 0 0 16px; padding-left: 22px; }
        li { margin: 0 0 7px; }
        li::marker { color: #90a4ae; }
        strong { color: #111827; font-weight: 600; }
      </style>
    </head>
    <body>
      <h1>MBS SAP Privacy Policy</h1>
      <p>This Privacy Policy explains how information is collected, used, stored, and protected when authorized users access MBS SAP (Mobile Safety Accountability Program).</p>
      <p>MBS SAP is owned by PT INDEXIM COALINDO and is <strong>developed and maintained by the System Integration Department of PT INDEXIM COALINDO</strong>.</p>

      <h2>1. Information We Process</h2>
      <p>Depending on the feature used, the Application may process:</p>
      <ul>
        <li>Employee identity and employment information, including NIK, name, position, department, and company.</li>
        <li>Safety reports, inspection answers, observations, coaching records, action plans, and related comments.</li>
        <li>Photos, videos, attachments, barcode or QR code results, and other evidence submitted by users.</li>
        <li>Device location and GPS coordinates when required for a safety report or field activity.</li>
        <li>Technical information needed for authentication, synchronization, security, and application diagnostics.</li>
      </ul>

      <h2>2. Purpose of Processing</h2>
      <p>Information is processed to operate safety programs, verify field activities, manage reports and corrective actions, measure safety performance, provide relevant updates, maintain audit records, and improve the reliability and security of MBS SAP.</p>

      <h2>3. Device Permissions</h2>
      <p>MBS SAP may request access to the camera, photo library, location, notifications, or local storage. Access is used only for features that require it, such as recording evidence, reading barcodes, obtaining report coordinates, sending safety updates, and supporting offline synchronization.</p>

      <h2>4. Access and Disclosure</h2>
      <p>Information may be accessed by authorized personnel of PT INDEXIM COALINDO and authorized business partners according to their duties and access rights. Information will not be sold. Disclosure may occur when required for company operations, safety investigations, audits, legal obligations, or protection of people and company assets.</p>

      <h2>5. Storage, Retention, and Security</h2>
      <p>Reasonable administrative and technical safeguards are applied to protect information against unauthorized access, alteration, loss, or disclosure. Information is retained according to operational, audit, safety, and legal requirements, then removed or archived under applicable company procedures.</p>

      <h2>6. User Responsibilities</h2>
      <ul>
        <li>Use an authorized account and keep login credentials confidential.</li>
        <li>Submit accurate, relevant, and appropriate information.</li>
        <li>Respect the privacy of other employees and business partners.</li>
        <li>Immediately report suspected misuse, unauthorized access, or security incidents through the applicable company channel.</li>
      </ul>

      <h2>7. Prohibited Actions</h2>
      <p>Users must not modify, copy, republish, manipulate, reverse engineer, decompile, bypass security controls, interfere with system operation, extract data without authorization, or use MBS SAP and its information for purposes outside authorized company activities.</p>

      <h2>8. Policy Updates</h2>
      <p>This Privacy Policy may be updated to reflect operational, technical, security, or regulatory changes. The latest version made available in MBS SAP applies to continued use of the Application.</p>

      <h2>9. Development and Maintenance</h2>
      <p>The design, development, system integration, technical operation, security improvement, and maintenance of MBS SAP are managed by the <strong>System Integration Department of PT INDEXIM COALINDO</strong>.</p>
    </body>
    </html>
    ''');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const TopBar(title: 'MBS SAP Privacy Policy'),
      body: WebViewWidget(controller: _webViewCtrl),
    );
  }
}

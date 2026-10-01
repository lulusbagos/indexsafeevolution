import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../widgets/top_bar.dart';

class LicenseAgreementPage extends StatefulWidget {
  const LicenseAgreementPage({super.key});

  @override
  State<LicenseAgreementPage> createState() => _LicenseAgreementPageState();
}

class _LicenseAgreementPageState extends State<LicenseAgreementPage> {
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
      <title>License Agreement</title>
      <style>
        * {
          box-sizing: border-box;
        }
        html {
          -webkit-text-size-adjust: 100%;
          text-size-adjust: 100%;
        }
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
          font-size: 21px;
          line-height: 1.35;
          font-weight: 700;
          color: #1565c0;
          letter-spacing: .2px;
          margin: 0 0 14px;
        }
        h2 {
          font-size: 17px;
          line-height: 1.4;
          font-weight: 600;
          color: #1f2937;
          letter-spacing: .1px;
          margin: 30px 0 12px;
          padding-top: 16px;
          border-top: 1px solid #eceff1;
        }
        p {
          margin: 0 0 14px;
        }
        ul {
          margin: 0 0 16px;
          padding-left: 22px;
        }
        li {
          margin: 0 0 7px;
        }
        li::marker {
          color: #90a4ae;
        }
        strong {
          font-weight: 600;
          color: #111827;
        }
      </style>
    </head>
    <body>
      <h1>MBS SAP License Agreement</h1>
      <p>This License Agreement governs the use of MBS SAP (Mobile Safety Accountability Program), hereinafter referred to as the "Application", owned by PT INDEXIM COALINDO and <strong>developed and maintained by the System Integration Department of PT INDEXIM COALINDO</strong>.</p>
      <h2>1. License Grant</h2>
      <p>The Company grants User a non-exclusive, non-transferable, revocable license to use the MBS SAP Application solely for internal business purposes related to safety and accountability within PT INDEXIM COALINDO.</p>
      <h2>2. Restrictions</h2>
      <p><strong>User shall not:</strong></p>
      <ul>
        <li>Modify, adapt, translate, or create derivative works based on the Application.</li>
        <li>Reverse engineer, decompile, or disassemble the Application.</li>
        <li>Rent, lease, lend, sell, sublicense, or otherwise transfer any rights in the Application.</li>
        <li>Remove any proprietary notices or labels on the Application.</li>
      </ul>
      <h2>3. Ownership</h2>
      <p>MBS SAP is and shall remain the exclusive property of PT INDEXIM COALINDO. The Application is developed and maintained by the System Integration Department of PT INDEXIM COALINDO. This Agreement does not grant User any ownership rights in the Application, source code, design, data structure, or related materials.</p>
      <h2>4. Confidentiality</h2>
      <p>User agrees to maintain the confidentiality of any proprietary information disclosed by the Company in connection with this Agreement. User shall not disclose such information to any third party without the prior written consent of the Company.</p>
      <h2>5. Updates and Maintenance</h2>
      <p>The System Integration Department of PT INDEXIM COALINDO may provide updates, maintenance, security improvements, and functional changes for MBS SAP. Any update or maintenance remains subject to this Agreement.</p>
      <h2>6. Term and Termination</h2>
      <p>This Agreement is effective until terminated. The Company may terminate this Agreement at any time if User breaches any of its terms. Upon termination, User shall cease all use of MBS SAP and destroy any copies in their possession or control.</p>
      <h2>7. Warranty Disclaimer</h2>
      <p>MBS SAP is provided "as is," without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose, and non-infringement. The Company does not warrant that the Application will meet User's requirements or that its operation will be uninterrupted or error-free.</p>
      <h2>8. Limitation of Liability</h2>
      <p>In no event shall the Company be liable for any indirect, incidental, special, or consequential damages, or damages for loss of profits, revenue, data, or use, incurred by User or any third party, whether in an action in contract or tort, arising from User's access to, or use of, MBS SAP.</p>
      <h2>9. Governing Law</h2>
      <p>This Agreement shall be governed by and construed in accordance with the laws of the Republic of Indonesia, without regard to its conflict of laws principles.</p>
      <h2>10. Entire Agreement</h2>
      <p>This Agreement constitutes the entire agreement between the parties concerning the subject matter hereof and supersedes all prior and contemporaneous understandings and agreements, whether written or oral, regarding such subject matter.</p>
      <h2>11. Severability</h2>
      <p>If any provision of this Agreement is found to be invalid or unenforceable, the remaining provisions shall remain in full force and effect.</p>
      <h2>12. Waiver</h2>
      <p>No waiver of any term of this Agreement shall be deemed a further or continuing waiver of such term or any other term.</p>
      <p><strong>IN WITNESS WHEREOF</strong>, the parties hereto have executed this License Agreement as of the date first written below.</p>
      <p><strong>Application developer and maintainer:</strong><br>System Integration Department<br>PT INDEXIM COALINDO</p>
    </body>
    </html>
    ''');
  }

  @override
  void dispose() {
    /** */

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const TopBar(title: 'MBS SAP License Agreement'),
      body: WebViewWidget(controller: _webViewCtrl),
    );
  }
}

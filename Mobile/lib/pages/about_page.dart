import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../widgets/top_bar.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
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
      <title>About MBS SAP</title>
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
        h3 {
          font-size: 15px;
          line-height: 1.45;
          font-weight: 600;
          color: #1565c0;
          margin: 20px 0 8px;
        }
        h4 {
          font-size: 14px;
          line-height: 1.45;
          font-weight: 600;
          color: #374151;
          margin: 16px 0 6px;
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
      </style>
    </head>
    <body>
      <h1>About MBS SAP</h1>
      <p>MBS SAP (Mobile Safety Accountability Program) is an official PT INDEXIM COALINDO mobile application that supports occupational safety management and employee accountability.</p>
      <p><strong>MBS SAP is developed and maintained by the System Integration Department of PT INDEXIM COALINDO.</strong> The department is responsible for the application's technical development, system integration, maintenance, and continuous improvement.</p>
      <p>MBS SAP helps employees report safety activities, monitor follow-up actions, and access safety performance information from one application.</p>
      <h2>Key Features</h2>
      <h3>1. Real-time Safety Monitoring</h3>
      <ul>
        <li>Track and monitor safety incidents in real-time.</li>
        <li>Immediate reporting and alerts for any safety hazards.</li>
      </ul>
      <h3>2. SAP Performance</h3>
      <ul>
        <li>Monitor SAP achievement and quality.</li>
        <li>View league standings and employee safety performance.</li>
      </ul>
      <h3>3. Incident Reporting</h3>
      <ul>
        <li>Easy and quick reporting of safety incidents via the mobile app.</li>
        <li>Include photos, descriptions, and location data in incident reports.</li>
      </ul>
      <h3>4. Action Plan</h3>
      <ul>
        <li>Create and monitor corrective action plans.</li>
        <li>Track assigned persons, due dates, progress, and completion.</li>
      </ul>
      <h3>5. Information and Reporting</h3>
      <ul>
        <li>Generate detailed reports on safety performance and incidents.</li>
        <li>Access incident information and SAP work roster data.</li>
      </ul>
      <h2>6. Benefits</h2>
      <h3>Enhanced Safety Culture</h3>
      <ul>
        <li>Promotes a proactive safety culture within the company.</li>
        <li>Empowers employees to take responsibility for their own safety and that of their colleagues.</li>
      </ul>
      <h3>Improved Compliance</h3>
      <ul>
        <li>Ensures compliance with safety regulations and standards.</li>
        <li>Streamlines safety documentation and record-keeping.</li>
      </ul>
      <h3>Efficient Incident Management</h3>
      <ul>
        <li>Reduces response time to safety incidents.</li>
        <li>Facilitates efficient and effective incident management and resolution.</li>
      </ul>
      <h2>7. Technology</h2>
      <h3>User-friendly Interface</h3>
      <ul>
        <li>Intuitive and easy-to-navigate interface for all users.</li>
        <li>Designed for use in challenging environments, including remote mining sites.</li>
      </ul>
      <h3>Secure and Reliable</h3>
      <ul>
        <li>Robust security features to protect sensitive safety data.</li>
        <li>Reliable performance even in low connectivity areas.</li>
      </ul>
      <h3>Cross-platform Compatibility</h3>
      <ul>
        <li>Available on both Android and iOS platforms.</li>
        <li>Seamlessly integrates with existing company systems and infrastructure.</li>
      </ul>
      <h2>Development and Maintenance</h2>
      <p>The design, development, system integration, technical operation, and maintenance of MBS SAP are managed by the <strong>System Integration Department of PT INDEXIM COALINDO</strong>.</p>
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
      appBar: const TopBar(title: 'About MBS SAP'),
      body: WebViewWidget(controller: _webViewCtrl),
    );
  }
}

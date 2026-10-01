import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../utils/links.dart';
import '../widgets/button_app.dart';
import '../widgets/top_bar.dart';
import 'menu/extra_page.dart';
import 'menu/ohs_page.dart';
import 'menu/sap_page.dart';

class YoutubePage extends StatefulWidget {
  const YoutubePage(this.title, this.videoId, {super.key});

  final String? title;
  final String? videoId;

  @override
  State<YoutubePage> createState() => _YoutubePageState();
}

class _YoutubePageState extends State<YoutubePage> {
  final _youtubeCtrl = YoutubePlayerController();

  @override
  void initState() {
    super.initState();

    if (widget.videoId != null) {
      _youtubeCtrl.loadVideoById(videoId: widget.videoId.toString());
    }
  }

  @override
  void dispose() {
    /** */

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TopBar(title: widget.title?.replaceAll('\n', ' ')),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            YoutubePlayer(controller: _youtubeCtrl),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white54,
                        border: Border.all(color: Colors.indigo.shade200),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(20)),
                      ),
                      width: 100,
                      height: 100,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/sap.png',
                            fit: BoxFit.fitHeight,
                            height: 55,
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'SAP',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onTap: () {
                      _youtubeCtrl.stopVideo();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (context) => const SapPage(),
                        ),
                      );
                    },
                  ),
                  InkWell(
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white54,
                        border: Border.all(color: Colors.indigo.shade200),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(20)),
                      ),
                      width: 100,
                      height: 100,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/ohs.png',
                            fit: BoxFit.fitHeight,
                            height: 55,
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'OHS',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onTap: () {
                      _youtubeCtrl.stopVideo();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (context) => const OhsPage(),
                        ),
                      );
                    },
                  ),
                  InkWell(
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white54,
                        border: Border.all(color: Colors.indigo.shade200),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(20)),
                      ),
                      width: 100,
                      height: 100,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/extras.png',
                            fit: BoxFit.fitHeight,
                            height: 55,
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Extra\'s',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onTap: () {
                      _youtubeCtrl.stopVideo();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (context) => const ExtraPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: CarouselSlider(
                options: CarouselOptions(
                  autoPlay: true,
                  autoPlayInterval: const Duration(seconds: 3),
                  autoPlayAnimationDuration: const Duration(milliseconds: 800),
                  autoPlayCurve: Curves.fastOutSlowIn,
                  pauseAutoPlayOnTouch: true,
                  onPageChanged: (index, reason) {},
                  viewportFraction: 1,
                  animateToClosest: true,
                ),
                items: listNews().map((element) {
                  return Builder(
                    builder: (BuildContext context) {
                      return Container(
                        width: MediaQuery.of(context).size.width,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade200),
                          image: DecorationImage(
                            image: AssetImage(element.image ?? ''),
                            fit: BoxFit.fitWidth,
                          ),
                        ),
                        child: Image.asset(
                          element.image ?? '',
                          fit: BoxFit.fitWidth,
                          opacity: const AlwaysStoppedAnimation(0),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 75),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: buttonApp(
          label: 'BACK',
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:photos/core/configuration.dart';
import 'package:photos/core/event_bus.dart';
import 'package:photos/events/local_photos_updated_event.dart';
import 'package:photos/models/filters/important_items_filter.dart';
import 'package:photos/models/file.dart';
import 'package:photos/file_repository.dart';
import 'package:photos/models/selected_files.dart';
import 'package:photos/photo_sync_manager.dart';
import 'package:photos/ui/device_folders_gallery_widget.dart';
import 'package:photos/ui/gallery.dart';
import 'package:photos/ui/gallery_app_bar_widget.dart';
import 'package:photos/ui/loading_photos_widget.dart';
import 'package:photos/ui/loading_widget.dart';
import 'package:photos/ui/memories_widget.dart';
import 'package:photos/ui/remote_folder_gallery_widget.dart';
import 'package:photos/ui/search_page.dart';
import 'package:photos/user_authenticator.dart';
import 'package:photos/utils/logging_util.dart';
import 'package:shake/shake.dart';
import 'package:logging/logging.dart';
import 'package:uni_links/uni_links.dart';

class HomeWidget extends StatefulWidget {
  final String title;

  const HomeWidget(this.title, {Key key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _HomeWidgetState();
}

class _HomeWidgetState extends State<HomeWidget> {
  static final importantItemsFilter = ImportantItemsFilter();
  final _logger = Logger("HomeWidgetState");
  final _remoteFolderGalleryWidget = RemoteFolderGalleryWidget();
  final _deviceFolderGalleryWidget = DeviceFolderGalleryWidget();
  final _selectedFiles = SelectedFiles();
  final _memoriesWidget = MemoriesWidget();

  ShakeDetector _detector;
  int _selectedNavBarItem = 0;
  StreamSubscription<LocalPhotosUpdatedEvent>
      _localPhotosUpdatedEventSubscription;

  @override
  void initState() {
    _detector = ShakeDetector.autoStart(
        shakeThresholdGravity: 3,
        onPhoneShake: () {
          _logger.info("Emailing logs");
          LoggingUtil.instance.emailLogs();
        });
    _localPhotosUpdatedEventSubscription =
        Bus.instance.on<LocalPhotosUpdatedEvent>().listen((event) {
      setState(() {});
    });
    _initDeepLinks();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GalleryAppBarWidget(
        GalleryAppBarType.homepage,
        widget.title,
        _selectedFiles,
        "/",
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      body: IndexedStack(
        children: <Widget>[
          PhotoSyncManager.instance.hasScannedDisk()
              ? _getMainGalleryWidget()
              : LoadingPhotosWidget(),
          _deviceFolderGalleryWidget,
          _remoteFolderGalleryWidget,
        ],
        index: _selectedNavBarItem,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (BuildContext context) {
                return SearchPage();
              },
            ),
          );
        },
        child: Icon(
          Icons.search,
          size: 28,
        ),
        elevation: 1,
        backgroundColor: Colors.black38,
        foregroundColor: Theme.of(context).accentColor,
      ),
    );
  }

  Future<bool> _initDeepLinks() async {
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      String initialLink = await getInitialLink();
      // Parse the link and warn the user, if it is not correct,
      // but keep in mind it could be `null`.
      if (initialLink != null) {
        _logger.info("Initial link received: " + initialLink);
        _getCredentials(context, initialLink);
        return true;
      } else {
        _logger.info("No initial link received.");
      }
    } on PlatformException {
      // Handle exception by warning the user their action did not succeed
      // return?
      _logger.severe("PlatformException thrown while getting initial link");
    }

    // Attach a listener to the stream
    getLinksStream().listen((String link) {
      _logger.info("Link received: " + link);
      _getCredentials(context, link);
    }, onError: (err) {
      _logger.severe(err);
    });
    return false;
  }

  void _getCredentials(BuildContext context, String link) {
    if (Configuration.instance.hasConfiguredAccount()) {
      return;
    }
    final ott = Uri.parse(link).queryParameters["ott"];
    _logger.info("Ott: " + ott);
    UserAuthenticator.instance.getCredentials(context, ott);
  }

  Widget _getMainGalleryWidget() {
    return FutureBuilder(
      future: FileRepository.instance.loadFiles().then((files) {
        return _getFilteredPhotos(files);
      }),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Gallery(
            syncLoader: () {
              return _getFilteredPhotos(FileRepository.instance.files);
            },
            reloadEvent: Bus.instance.on<LocalPhotosUpdatedEvent>(),
            onRefresh: PhotoSyncManager.instance.sync,
            tagPrefix: "home_gallery",
            selectedFiles: _selectedFiles,
            headerWidget: _memoriesWidget,
          );
        } else if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        } else {
          return loadWidget;
        }
      },
    );
  }

  BottomNavigationBar _buildBottomNavigationBar() {
    return BottomNavigationBar(
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.photo_library),
          title: Text('Photos'),
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.folder),
          title: Text('Folders'),
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.folder_shared),
          title: Text('Shared'),
        ),
      ],
      currentIndex: _selectedNavBarItem,
      selectedItemColor: Theme.of(context).accentColor,
      onTap: (index) {
        setState(() {
          _selectedNavBarItem = index;
        });
      },
    );
  }

  List<File> _getFilteredPhotos(List<File> unfilteredFiles) {
    _logger.info("Filtering " + unfilteredFiles.length.toString());
    final List<File> filteredPhotos = List<File>();
    for (File file in unfilteredFiles) {
      if (importantItemsFilter.shouldInclude(file)) {
        filteredPhotos.add(file);
      }
    }
    _logger.info("Filtered down to " + filteredPhotos.length.toString());
    return filteredPhotos;
  }

  @override
  void dispose() {
    _detector.stopListening();
    _localPhotosUpdatedEventSubscription.cancel();
    super.dispose();
  }
}

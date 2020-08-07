import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:photos/core/event_bus.dart';
import 'package:photos/db/files_db.dart';
import 'package:photos/events/local_photos_updated_event.dart';
import 'package:photos/favorite_files_repository.dart';
import 'package:photos/models/device_folder.dart';
import 'package:photos/models/filters/favorite_items_filter.dart';
import 'package:photos/models/filters/folder_name_filter.dart';
import 'package:photos/models/filters/video_file_filter.dart';
import 'package:photos/ui/device_folder_page.dart';
import 'package:photos/ui/loading_widget.dart';
import 'package:photos/ui/thumbnail_widget.dart';
import 'package:path/path.dart' as p;

class DeviceFolderGalleryWidget extends StatefulWidget {
  final isRemote;
  const DeviceFolderGalleryWidget({
    this.isRemote = false,
    Key key,
  }) : super(key: key);

  @override
  _DeviceFolderGalleryWidgetState createState() =>
      _DeviceFolderGalleryWidgetState();
}

class _DeviceFolderGalleryWidgetState extends State<DeviceFolderGalleryWidget> {
  StreamSubscription<LocalPhotosUpdatedEvent> _subscription;

  @override
  void initState() {
    _subscription = Bus.instance.on<LocalPhotosUpdatedEvent>().listen((event) {
      setState(() {});
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _getDeviceFolders(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return _getDeviceFolderGalleryWidget(snapshot.data);
        } else if (snapshot.hasError) {
          return Text(snapshot.error.toString());
        } else {
          return loadWidget;
        }
      },
    );
  }

  Widget _getDeviceFolderGalleryWidget(List<DeviceFolder> folders) {
    return Container(
      margin: EdgeInsets.only(top: 24),
      child: GridView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.only(bottom: 12),
        physics: ScrollPhysics(), // to disable GridView's scrolling
        itemBuilder: (context, index) {
          return _buildFolder(context, folders[index]);
        },
        itemCount: folders.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
        ),
      ),
    );
  }

  Future<List<DeviceFolder>> _getDeviceFolders() async {
    final paths = await FilesDB.instance.getLocalPaths();
    final folders = List<DeviceFolder>();
    final allowedRemoteFolders =
        ["WhatsApp Profile Photos", "Download"].toSet();
    for (final path in paths) {
      log(path);
      if (widget.isRemote) {
        if (!allowedRemoteFolders.contains(path)) {
          continue;
        }
      } else {
        if (allowedRemoteFolders.contains(path)) {
          continue;
        }
      }
      final file = await FilesDB.instance.getLatestFileInPath(path);
      var folderName = p.basename(path);
      if (widget.isRemote) {
        folderName = folderName == "WhatsApp Profile Photos"
            ? "Shanthy's Camera"
            : "Santorini";
      }
      folders.add(DeviceFolder(folderName, path, file, FolderNameFilter(path)));
    }
    folders.sort((first, second) {
      return second.thumbnail.creationTime
          .compareTo(first.thumbnail.creationTime);
    });
    if (!widget.isRemote && FavoriteFilesRepository.instance.hasFavorites()) {
      final file = await FilesDB.instance.getLatestFileAmongGeneratedIds(
          FavoriteFilesRepository.instance.getLiked().toList());
      folders.insert(0,
          DeviceFolder("Favorites", "/Favorites", file, FavoriteItemsFilter()));
    }
    // final videos = await FilesDB.instance.getAllVideos();
    // if (videos.length > 0) {
    //   folders.insert(
    //       0, DeviceFolder("Videos", "/Videos", videos[0], VideoFileFilter()));
    // }
    return folders;
  }

  Widget _buildFolder(BuildContext context, DeviceFolder folder) {
    return GestureDetector(
      child: Column(
        children: <Widget>[
          Container(
            child: Hero(
                tag: "device_folder:" + folder.path + folder.thumbnail.tag(),
                child: ThumbnailWidget(folder.thumbnail)),
            height: 150,
            width: 150,
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              folder.name,
              style: TextStyle(
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (BuildContext context) {
              return DeviceFolderPage(folder);
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

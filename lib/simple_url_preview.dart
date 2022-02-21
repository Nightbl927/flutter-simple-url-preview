library simple_url_preview;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart';
import 'package:http/http.dart';
import 'package:simple_url_preview/widgets/preview_description.dart';
import 'package:simple_url_preview/widgets/preview_image.dart';
import 'package:simple_url_preview/widgets/preview_site_name.dart';
import 'package:simple_url_preview/widgets/preview_title.dart';
import 'package:string_validator/string_validator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

/// Provides URL preview
class SimpleUrlPreview extends StatefulWidget {
  /// URL for which preview is to be shown
  final String url;

  /// Height of the preview
  final double previewHeight;

  /// Whether or not to show close button for the preview
  final bool? isClosable;

  /// Background color
  final Color? bgColor;

  /// Style of Title.
  final TextStyle? titleStyle;

  /// Number of lines for Title. (Max possible lines = 2)
  final int titleLines;

  /// Style of Description
  final TextStyle? descriptionStyle;

  /// Number of lines for Description. (Max possible lines = 3)
  final int descriptionLines;

  /// Style of site title
  final TextStyle? siteNameStyle;

  /// Color for loader icon shown, till image loads
  final Color? imageLoaderColor;

  /// Container padding
  final EdgeInsetsGeometry? previewContainerPadding;

  /// onTap URL preview, by default opens URL in default browser
  final VoidCallback? onTap;

  SimpleUrlPreview({
    required this.url,
    this.previewHeight = 130.0,
    this.isClosable,
    this.bgColor,
    this.titleStyle,
    this.titleLines = 2,
    this.descriptionStyle,
    this.descriptionLines = 3,
    this.siteNameStyle,
    this.imageLoaderColor,
    this.previewContainerPadding,
    this.onTap,
  }) : assert(previewHeight >= 130.0,
        'The preview height should be greater than or equal to 130'),
      assert(titleLines <= 2 && titleLines > 0,
        'The title lines should be less than or equal to 2 and not equal to 0'),
      assert(descriptionLines <= 3 && descriptionLines > 0,
        'The description lines should be less than or equal to 3 and not equal to 0');

  @override
  _SimpleUrlPreviewState createState() => _SimpleUrlPreviewState();
}

class _SimpleUrlPreviewState extends State<SimpleUrlPreview> {
  Map? _urlPreviewData;
  bool _isVisible = true;
  late bool _isClosable;
  double? _previewHeight;
  Color? _bgColor;
  TextStyle? _titleStyle;
  int? _titleLines;
  TextStyle? _descriptionStyle;
  int? _descriptionLines;
  TextStyle? _siteNameStyle;
  Color? _imageLoaderColor;
  EdgeInsetsGeometry? _previewContainerPadding;
  VoidCallback? _onTap;

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _getUrlData();
  }

  void _initialize() {
    _previewHeight = widget.previewHeight;
    _descriptionStyle = widget.descriptionStyle;
    _descriptionLines = widget.descriptionLines;
    _titleStyle = widget.titleStyle;
    _titleLines = widget.titleLines;
    _siteNameStyle = widget.siteNameStyle;
    _previewContainerPadding = widget.previewContainerPadding;
    _onTap = widget.onTap ?? _launchURL;
  }

  void _getUrlData() async {
    setState(() {
      _loading = true;
    });

    if (!isURL(widget.url)) {
      setState(() {
        _urlPreviewData = null;
      });
      return;
    }

    var response = await get(Uri.parse(widget.url));
    if (response.statusCode != 200) {
      if (!this.mounted) {
        return;
      }
      setState(() {
        _urlPreviewData = null;
      });
    }

    var document = parse(response.body);
    Map data = {};
    _extractOGData(document, data, 'og:title');
    _extractOGData(document, data, 'og:description');
    _extractOGData(document, data, 'og:site_name');
    _extractOGData(document, data, 'og:image');

    if (!this.mounted) {
      return;
    }

    if (data.isNotEmpty) {
      setState(() {
        _urlPreviewData = data;
        _isVisible = true;
      });
    }

    setState(() {
      _loading = false;
    });
  }

  void _extractOGData(dom.Document document, Map data, String parameter) {
    var titleMetaTag = document
      .getElementsByTagName("meta")
      .firstWhereOrNull((meta) => meta.attributes['property'] == parameter);
    if (titleMetaTag != null) {
      data[parameter] = titleMetaTag.attributes['content'];
    }
    else {
      if(parameter == 'og:title') {
        if(document.getElementsByTagName("title").isNotEmpty) {
          data[parameter] = document.getElementsByTagName("title")[0].text;
        }
      }
      else if(parameter == 'og:image') {
        var titleMetaTag = document
          .getElementsByTagName("meta")
          .firstWhereOrNull((meta) => meta.attributes['itemprop'] == 'image');
        if (titleMetaTag != null) {
          String _imagePart = "";

          if(titleMetaTag.attributes['content'] != null) {
            _imagePart = titleMetaTag.attributes['content']!;
          }

          data[parameter] = widget.url + "/" + _imagePart;
        }
        else {
          var titleMetaTag = document
            .getElementsByTagName("meta")
            .firstWhereOrNull((meta) => meta.attributes['name'] == 'image');

          if (titleMetaTag != null) {
            data[parameter] = titleMetaTag.attributes['content'];
          }
        }
      }
      else if(parameter == 'og:description') {
        var titleMetaTag = document
            .getElementsByTagName("meta")
            .firstWhereOrNull((meta) => meta.attributes['name'] == 'description');
        if (titleMetaTag != null) {
          data[parameter] = titleMetaTag.attributes['content'];
        }
      }
    }
  }

  void _extractStandardData(dom.Document document, Map data, String parameter) {
    var titleMetaTag = document
        .getElementsByTagName("meta")
        .firstWhereOrNull((meta) => meta.attributes['property'] == parameter);
    if (titleMetaTag != null) {
      data[parameter] = titleMetaTag.attributes['content'];
    }
  }

  void _launchURL() async {
    if (await canLaunch(Uri.encodeFull(widget.url))) {
      await launch(Uri.encodeFull(widget.url));
    } else {
      throw 'Could not launch ${widget.url}';
    }
  }

  @override
  Widget build(BuildContext context) {
    _isClosable = widget.isClosable ?? false;
    _bgColor = widget.bgColor ?? Theme.of(context).primaryColor;
    _imageLoaderColor = widget.imageLoaderColor ?? Theme.of(context).accentColor;
    _initialize();

    return Container(
      child: _loading == false ? (_urlPreviewData == null || !_isVisible) ? SizedBox.shrink() : Container(
        padding: _previewContainerPadding,
        child: GestureDetector(
          onTap: _onTap,
          onLongPress: () {},
          child: _buildPreviewCard(context),
        ), //_buildClosablePreview(),
      ) : Card(
        margin: EdgeInsets.fromLTRB(0.0, 8.0, 0.0, 8.0),
        elevation: 0,
        color: _bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
            child: SpinKitThreeBounce(
              color: Theme.of(context).indicatorColor,
              size: 50.0,
            ),
          )
        ),
      ),
    );
  }

  Widget _buildClosablePreview() {
    return _isClosable ? Align(
      alignment: Alignment.topRight,
      child: IconButton(
        icon: Icon(
          Icons.clear,
        ),
        onPressed: () {
          setState(() {
            _isVisible = false;
          });
        },
      ),
    ) : SizedBox();
  }

  Card _buildPreviewCard(BuildContext context) {
    return Card(
      margin: EdgeInsets.fromLTRB(0.0, 8.0, 0.0, 8.0),
      elevation: 0,
      color: _bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PreviewImage(
            _urlPreviewData!['og:image'],
            _imageLoaderColor,
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  PreviewTitle(
                    _urlPreviewData!['og:title'],
                    _titleStyle == null ? TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).indicatorColor,
                    ) : _titleStyle,
                    _titleLines
                  ),
                  PreviewDescription(
                    _urlPreviewData!['og:description'],
                    _descriptionStyle == null ? TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).accentColor,
                    ) : _descriptionStyle,
                    _descriptionLines,
                  ),
                  PreviewSiteName(
                    widget.url,
                    _siteNameStyle == null ? TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).accentColor,
                    ) : _siteNameStyle,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

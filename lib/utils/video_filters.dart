import 'package:flutter/material.dart';

class VideoFilter {
  final String name;
  final ColorFilter? colorFilter;

  const VideoFilter({required this.name, required this.colorFilter});
}

const List<VideoFilter> kVideoFilters = [
  VideoFilter(name: 'なし', colorFilter: null),
  VideoFilter(
    name: 'ウォーム',
    colorFilter: ColorFilter.matrix([
      1.3, 0.1, 0.0, 0, 0,
      0.0, 1.0, 0.0, 0, 0,
      0.0, 0.0, 0.7, 0, 0,
      0.0, 0.0, 0.0, 1, 0,
    ]),
  ),
  VideoFilter(
    name: 'クール',
    colorFilter: ColorFilter.matrix([
      0.8, 0.0, 0.0, 0, 0,
      0.0, 0.9, 0.1, 0, 0,
      0.0, 0.0, 1.3, 0, 0,
      0.0, 0.0, 0.0, 1, 0,
    ]),
  ),
  VideoFilter(
    name: 'モノクロ',
    colorFilter: ColorFilter.matrix([
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0.0,    0.0,    0.0,    1, 0,
    ]),
  ),
  VideoFilter(
    name: 'ヴィンテージ',
    colorFilter: ColorFilter.matrix([
      0.9, 0.2, 0.1, 0, 10,
      0.1, 0.8, 0.1, 0, 5,
      0.0, 0.0, 0.7, 0, 0,
      0.0, 0.0, 0.0, 1, 0,
    ]),
  ),
  VideoFilter(
    name: 'ビビッド',
    colorFilter: ColorFilter.matrix([
      1.5, 0.0, 0.0, 0, 0,
      0.0, 1.5, 0.0, 0, 0,
      0.0, 0.0, 1.5, 0, 0,
      0.0, 0.0, 0.0, 1, 0,
    ]),
  ),
];

class MediaLimits {
  static const int maxPhotoBytes = 10 * 1024 * 1024;
  static const int maxVideoBytes = 100 * 1024 * 1024;

  // Lower quality a bit to keep uploads lighter while staying acceptable visually.
  static const int postImageQuality = 78;
  static const int avatarImageQuality = 72;
}

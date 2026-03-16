class FirebaseWebConfig {
  static const apiKey = 'AIzaSyBn6VHGz1Srkcd-nO85NaWe9N8NykTP0Mo';
  static const appId = '1:460437609061:web:8b0b6e5c136fab52d8c48c';
  static const messagingSenderId = '460437609061';
  static const projectId = 'allonssy';
  static const authDomain = 'allonssy.firebaseapp.com';
  static const storageBucket = 'allonssy.firebasestorage.app';
  static const measurementId = '';
  static const vapidKey =
      'BDRzNky38hzb9oSPWtvbcZhxYX38kdUPGpwAjZ4IdL4gswTWaG0JO5Sjw-oceCmOj_x0ZMgETyg7mRtpClaHIrY';

  static bool get isConfigured =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      projectId.isNotEmpty &&
      vapidKey.isNotEmpty;
}

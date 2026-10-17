import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BookingMediaRepository {
  final SupabaseClient client;
  BookingMediaRepository(this.client);
  Future<List<String>> upload({
    required String userId,
    required List<XFile> files,
  }) async {
    final urls = <String>[];
    for (final file in files) {
      final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
      final path =
          '$userId/${DateTime.now().microsecondsSinceEpoch}_${urls.length}.$ext';
      await client.storage
          .from('booking-photos')
          .uploadBinary(
            path,
            await file.readAsBytes(),
            fileOptions: FileOptions(contentType: 'image/$ext'),
          );
      urls.add(client.storage.from('booking-photos').getPublicUrl(path));
    }
    return urls;
  }
}

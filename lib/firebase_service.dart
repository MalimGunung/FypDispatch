import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // ✅ Save scanned parcel data
  Future<void> saveParcelData(String address, double latitude, double longitude) async {
    try {
      await firestore.collection("parcels").add({
        "address": address.trim(),
        "latitude": latitude,
        "longitude": longitude,
        "timestamp": FieldValue.serverTimestamp(),
      });
      print("✅ Parcel saved: $address | Lat: $latitude | Lon: $longitude");
    } catch (e) {
      print("❌ Error saving parcel to Firestore: $e");
    }
  }

  // ✅ Fetch stored addresses from Firebase
  Future<List<Map<String, dynamic>>> getStoredAddresses() async {
    List<Map<String, dynamic>> addressList = [];
    try {
      QuerySnapshot snapshot = await firestore.collection("parcels").get();

      print("📥 Total documents fetched from Firebase: ${snapshot.docs.length}");

      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;

        if (data.containsKey("latitude") && data.containsKey("longitude") && data.containsKey("address")) {
          addressList.add({
            "id": doc.id,
            "address": data["address"],
            "latitude": data["latitude"],
            "longitude": data["longitude"],
          });

          print("✅ Retrieved Address: ${data['address']} | Lat: ${data['latitude']} | Lon: ${data['longitude']}");
        } else {
          print("❌ Missing fields in document: ${doc.id}");
        }
      }

      if (addressList.isEmpty) {
        print("❌ No valid addresses found in Firestore.");
      }
    } catch (e) {
      print("❌ Error fetching addresses from Firestore: $e");
    }

    return addressList;
  }

  // ✅ Delete address from Firestore
  Future<void> deleteParcel(String documentId) async {
    try {
      await firestore.collection("parcels").doc(documentId).delete();
      print("🗑️ Parcel deleted: $documentId");
    } catch (e) {
      print("❌ Error deleting parcel: $e");
    }
  }

  // ✅ Update address in Firestore
  Future<void> updateParcel(String documentId, String newAddress, double newLatitude, double newLongitude) async {
    try {
      await firestore.collection("parcels").doc(documentId).update({
        "address": newAddress.trim(),
        "latitude": newLatitude,
        "longitude": newLongitude,
      });
      print("✏️ Parcel updated: $documentId");
    } catch (e) {
      print("❌ Error updating parcel: $e");
    }
  }
}

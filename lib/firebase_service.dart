import 'package:cloud_firestore/cloud_firestore.dart';


class FirebaseService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add delivery status to parcel data
  Future<void> saveParcelData(String address, double latitude, double longitude) async {
    try {
      await firestore.collection("parcels").add({
        "address": address.trim(),
        "latitude": latitude,
        "longitude": longitude,
        "timestamp": FieldValue.serverTimestamp(),
        "status": "pending", // Add status field
      });
      print("✅ Parcel saved: $address | Lat: $latitude | Lon: $longitude");
    } catch (e) {
      print("❌ Error saving parcel to Firestore: $e");
    }
  }

  // Update delivery status
  Future<void> updateDeliveryStatus(String documentId, String status) async {
    try {
      await firestore.collection("parcels").doc(documentId).update({
        "status": status,
      });
      print("✅ Delivery status updated for: $documentId");
    } catch (e) {
      print("❌ Error updating delivery status: $e");
    }
  }

  // Move completed deliveries to historical data
  Future<void> moveToHistory(List<String> documentIds) async {
    try {
      // Get today's date in YYYY-MM-DD format
      String today = DateTime.now().toIso8601String().split('T')[0];
      
      // Batch write
      WriteBatch batch = firestore.batch();
      
      // Get all parcels that need to be moved
      for (String docId in documentIds) {
        DocumentSnapshot parcel = await firestore.collection("parcels").doc(docId).get();
        Map<String, dynamic> data = parcel.data() as Map<String, dynamic>;
        
        // Create historical record
        DocumentReference historyRef = firestore
            .collection("delivery_history")
            .doc(today)
            .collection("deliveries")
            .doc(docId);
            
        batch.set(historyRef, {
          ...data,
          "completedAt": FieldValue.serverTimestamp(),
        });
        
        // Delete from active parcels
        batch.delete(firestore.collection("parcels").doc(docId));
      }
      
      await batch.commit();
      print("✅ Moved ${documentIds.length} deliveries to history");
    } catch (e) {
      print("❌ Error moving to history: $e");
    }
  }

  // Get historical delivery data for a specific date
  Future<List<Map<String, dynamic>>> getHistoricalDeliveries(String date) async {
    List<Map<String, dynamic>> deliveries = [];
    try {
      QuerySnapshot snapshot = await firestore
          .collection("delivery_history")
          .doc(date)
          .collection("deliveries")
          .get();

      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        deliveries.add({
          "id": doc.id,
          ...data,
        });
      }
    } catch (e) {
      print("❌ Error fetching historical deliveries: $e");
    }
    return deliveries;
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

  // ✅ Add this method to delete all parcels
  Future<void> deleteAllParcels() async {
    final snapshot = await _firestore.collection('parcels').get();
    for (var doc in snapshot.docs) {
      await _firestore.collection('parcels').doc(doc.id).delete();
    }
  }

}

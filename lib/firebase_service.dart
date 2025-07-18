import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add delivery status to parcel data
  Future<void> saveParcelData(String userEmail, String address, double latitude,
      double longitude, {int? scanOrder}) async {
    try {
      await firestore
          .collection("dispatcher")
          .doc(userEmail)
          .collection("parcels")
          .add({
        "address": address.trim(),
        "latitude": latitude,
        "longitude": longitude,
        "timestamp": FieldValue.serverTimestamp(),
        "status": "pending",
        if (scanOrder != null) "scanOrder": scanOrder, // <-- Store scanOrder
      });
      print(
          "✅ Parcel saved for user $userEmail: $address | Lat: $latitude | Lon: $longitude | ScanOrder: $scanOrder");
    } catch (e) {
      print("❌ Error saving parcel to Firestore for user $userEmail: $e");
    }
  }

  // Update delivery status
  Future<void> updateDeliveryStatus(
      String userEmail, String documentId, String status) async {
    try {
      await firestore
          .collection("dispatcher")
          .doc(userEmail)
          .collection("parcels")
          .doc(documentId)
          .update({
        "status": status,
      });
      print("✅ Delivery status updated for user $userEmail, doc: $documentId");
    } catch (e) {
      print("❌ Error updating delivery status for user $userEmail: $e");
    }
  }

  // Move completed deliveries to historical data
  Future<void> moveToHistory(String userEmail, List<String> documentIds) async {
    try {
      String today = DateTime.now().toIso8601String().split('T')[0];
      WriteBatch batch = firestore.batch();
      for (String docId in documentIds) {
        DocumentSnapshot parcel = await firestore
            .collection("dispatcher")
            .doc(userEmail)
            .collection("parcels")
            .doc(docId)
            .get();
        Map<String, dynamic> data = parcel.data() as Map<String, dynamic>;
        DocumentReference historyRef = firestore
            .collection("dispatcher")
            .doc(userEmail)
            .collection("delivery_history")
            .doc(today)
            .collection("deliveries")
            .doc(docId);
        batch.set(historyRef, {
          ...data,
          "completedAt": FieldValue.serverTimestamp(),
        });
        batch.delete(firestore
            .collection("dispatcher")
            .doc(userEmail)
            .collection("parcels")
            .doc(docId));
      }
      await batch.commit();
      print(
          "✅ Moved ${documentIds.length} deliveries to history for user $userEmail");
    } catch (e) {
      print("❌ Error moving to history for user $userEmail: $e");
    }
  }

  // Get historical delivery data for a specific date
  Future<List<Map<String, dynamic>>> getHistoricalDeliveries(
      String userEmail, String date) async {
    List<Map<String, dynamic>> deliveries = [];
    try {
      QuerySnapshot snapshot = await firestore
          .collection("dispatcher")
          .doc(userEmail)
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
      print("❌ Error fetching historical deliveries for user $userEmail: $e");
    }
    return deliveries;
  }

  // Fetch stored addresses from Firebase
// Fetch stored addresses from Firebase
Future<List<Map<String, dynamic>>> getStoredAddresses(
    String userEmail) async {
  List<Map<String, dynamic>> addressList = [];
  try {
    QuerySnapshot snapshot = await firestore
        .collection("dispatcher")
        .doc(userEmail)
        .collection("parcels")
        .orderBy("scanOrder", descending: false) // <-- Order by scanOrder
        .get();

    print(
        "📥 Total documents fetched from Firebase for user $userEmail: ${snapshot.docs.length}");

    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;

      if (data.containsKey("latitude") &&
          data.containsKey("longitude") &&
          data.containsKey("address")) {
        addressList.add({
          "id": doc.id,
          "address": data["address"],
          "latitude": data["latitude"],
          "longitude": data["longitude"],
          "timestamp": data["timestamp"],
          "scanOrder": data["scanOrder"], // <-- Use scanOrder from Firestore
        });
        print(
            "✅ Retrieved Address (Scan #${data['scanOrder'] ?? '?' }): ${data['address']}");
      } else {
        print("❌ Missing fields in document: ${doc.id}");
      }
    }

    if (addressList.isEmpty) {
      print("❌ No valid addresses found in Firestore for user $userEmail.");
    }
  } catch (e) {
    print(
        "❌ Error fetching addresses from Firestore for user $userEmail: $e");
  }
  return addressList;
}

  // Delete address from Firestore
  Future<void> deleteParcel(String userEmail, String documentId) async {
    try {
      await firestore
          .collection("dispatcher")
          .doc(userEmail)
          .collection("parcels")
          .doc(documentId)
          .delete();
      print("🗑️ Parcel deleted for user $userEmail: $documentId");
    } catch (e) {
      print("❌ Error deleting parcel for user $userEmail: $e");
    }
  }

  // Update address in Firestore
  Future<void> updateParcel(String userEmail, String documentId,
      String newAddress, double newLatitude, double newLongitude) async {
    try {
      await firestore
          .collection("dispatcher")
          .doc(userEmail)
          .collection("parcels")
          .doc(documentId)
          .update({
        "address": newAddress.trim(),
        "latitude": newLatitude,
        "longitude": newLongitude,
      });
      print("✏️ Parcel updated for user $userEmail: $documentId");
    } catch (e) {
      print("❌ Error updating parcel for user $userEmail: $e");
    }
  }

  // Delete all parcels
  Future<void> deleteAllParcels(String userEmail) async {
    final snapshot = await _firestore
        .collection('dispatcher')
        .doc(userEmail)
        .collection('parcels')
        .get();
    for (var doc in snapshot.docs) {
      await _firestore
          .collection('dispatcher')
          .doc(userEmail)
          .collection('parcels')
          .doc(doc.id)
          .delete();
    }
    print("🗑️ All parcels deleted for user $userEmail");
  }

  Future<void> saveRouteSummary(String userEmail,
      {required double distance,
      required int time,
      required int totalAddresses}) async {
    try {
      await firestore
          .collection("dispatcher")
          .doc(userEmail)
          .collection("route_summaries")
          .add({
        'distance': distance,
        'time': time,
        'totalAddresses': totalAddresses,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("❌ Error saving route summary: $e");
    }
  }

  // Fetch the latest route summary for the user
  Future<Map<String, dynamic>?> getRouteSummary(String? userEmail) async {
    if (userEmail == null) return null;
    try {
      final query = await firestore
          .collection("dispatcher")
          .doc(userEmail)
          .collection("route_summaries")
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        return {
          'distance': data['distance'],
          'time': data['time'],
          'totalAddresses': data['totalAddresses'],
          'timestamp': data['timestamp'].toDate().toIso8601String(),
        };
      }
      return null;
    } catch (e) {
      print("❌ Error fetching route summary: $e");
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAllRoutes(String? userEmail) async {
    if (userEmail == null) return [];
    try {
      final querySnapshot = await firestore
          .collection("dispatcher")
          .doc(userEmail)
          .collection("route_summaries")
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'distance': data['distance'],
          'time': data['time'],
          'totalAddresses': data['totalAddresses'],
          'timestamp': data['timestamp'].toDate().toIso8601String(),
        };
      }).toList();
    } catch (e) {
      print("❌ Error fetching all routes: $e");
      return [];
    }
  }
}
  

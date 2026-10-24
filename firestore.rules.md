rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isAdmin() {
      return request.auth != null &&
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    function isAssignedDriverNotification() {
      return request.auth != null &&
        request.resource.data.requestId is string &&
        exists(/databases/$(database)/documents/shipmentRequests/$(request.resource.data.requestId)) &&
        get(/databases/$(database)/documents/shipmentRequests/$(request.resource.data.requestId)).data.driverId == request.auth.uid &&
        get(/databases/$(database)/documents/shipmentRequests/$(request.resource.data.requestId)).data.customerId == request.resource.data.userId;
    }

    match /users/{userId} {
      allow create: if request.auth != null && request.auth.uid == userId;
      allow get: if request.auth != null && request.auth.uid == userId;
      allow list: if request.auth != null;
      allow update: if request.auth != null && (request.auth.uid == userId ||
        (isAdmin() && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['isAvailable', 'assignedRequestId'])));
      allow delete: if request.auth != null && request.auth.uid == userId;
    }

match /phoneLoginLookups/{lookupId} {
  allow get: if true;
  allow create, update: if request.auth != null;
  allow delete, list: if false;
}

    // Read-only fleet catalog for the customer dashboard and search. Writes
    // are open to any authenticated user for now so the app
    // can seed/manage demo data before an admin-only fleet management
    // screen exists; tighten to isAdmin() once that's built.
    match /vehicleCategories/{categoryId} {
      allow get, list: if request.auth != null;
      allow create, update, delete: if request.auth != null;
    }

match /fleetVehicles/{vehicleId} {
  allow get, list: if request.auth != null;
  allow create, update, delete: if request.auth != null;
}

    // Customers create their own requests and can read/update their own
    // (needed to pay the commitment
    // fee and for the client-triggered auto-cancel check); drivers can read
    // requests assigned to them; admins can
    // read/update any request to approve/reject/assign it. NOTE: allowing
    // the owning customer to update is broader than ideal (they could in
    // principle edit other fields on their own doc) — a production version
    // should replace this with field-level rules or move payment/expiry
    // writes to a Cloud Function.
    match /shipmentRequests/{requestId} {
      allow create: if request.auth != null && request.auth.uid == request.resource.data.customerId;
      allow get, list: if request.auth != null &&
        (request.auth.uid == resource.data.customerId ||
         request.auth.uid == resource.data.driverId ||
         isAdmin());
      allow update: if isAdmin() ||
        (request.auth != null && request.auth.uid == resource.data.customerId) ||
        (request.auth != null && request.auth.uid == resource.data.driverId &&
         request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status', 'statusUpdatedAt', 'deliveredAt', 'proofOfDelivery', 'liveLocation', 'locationUpdatedAt']));
      allow delete: if false;
    }

    // In-app notifications: admins write them on approve/reject; users may
    // write their own, and assigned drivers may
    // notify the customer on shipment status changes.
    match /notifications/{notificationId} {
      allow create: if isAdmin() ||
        (request.auth != null && request.auth.uid == request.resource.data.userId) ||
        isAssignedDriverNotification();
      allow get, list: if request.auth != null && request.auth.uid == resource.data.userId;
      allow update: if request.auth != null && request.auth.uid == resource.data.userId;
      allow delete: if false;
    }

    match /fcmTokens/{tokenId} {
      allow create, update: if request.auth != null && request.resource.data.userId == request.auth.uid;
      allow read, delete: if request.auth != null && resource.data.userId == request.auth.uid;
    }

    match /payments/{paymentId} {
      allow create: if request.auth != null && request.resource.data.userId == request.auth.uid;
      allow get: if request.auth != null && (resource.data.userId == request.auth.uid || isAdmin());
      allow update: if isAdmin();
      allow list, delete: if false;
    }
  }
}

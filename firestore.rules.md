rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isAdmin() {
      return request.auth != null &&
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    match /users/{userId} {
      allow create: if request.auth != null && request.auth.uid == userId;
      allow get: if request.auth != null && request.auth.uid == userId;
      allow list: if request.auth != null;
      allow update, delete: if request.auth != null && request.auth.uid == userId;
    }

match /phoneLoginLookups/{lookupId} {
  allow get: if true;
  allow create, update: if request.auth != null;
  allow delete, list: if false;
}

    // FR-02 / FR-03: read-only fleet catalog for the customer dashboard and
    // search. Writes are open to any authenticated user for now so the app
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

    // FR-06 / FR-07 / FR-08 / FR-10 / FR-11: customers create their own
    // requests and can read/update their own (needed to pay the commitment
    // fee and for the client-triggered auto-cancel check); drivers can read
    // requests assigned to them (FR-10 driver dashboard); admins can
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
      allow update: if isAdmin() || (request.auth != null && request.auth.uid == resource.data.customerId);
      allow delete: if false;
    }

    // In-app notifications (FR-16 stand-in): admins write them on
    // approve/reject; a user may also write (and read/mark-read) their own,
    // since FR-11's client-triggered auto-cancel notifies from the
    // customer's own session rather than an admin one.
    match /notifications/{notificationId} {
      allow create: if isAdmin() || (request.auth != null && request.auth.uid == request.resource.data.userId);
      allow get, list: if request.auth != null && request.auth.uid == resource.data.userId;
      allow update: if request.auth != null && request.auth.uid == resource.data.userId;
      allow delete: if false;
    }
  }
}
                                                                                                                                                                                                        
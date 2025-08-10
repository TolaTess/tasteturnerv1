# User Deletion Service

This service provides comprehensive functionality to delete user data from the TasteTurner app.

## Features

- **Complete Data Deletion**: Removes user data from all Firebase collections
- **Account Deletion**: Optionally deletes the Firebase Auth account
- **Storage Cleanup**: Deletes associated media files from Firebase Storage
- **Local Storage Cleanup**: Clears all local app data
- **Safety Checks**: Includes confirmation dialogs and error handling

## Usage

### Basic Usage

```dart
// Delete user data only (keeps Firebase Auth account)
final success = await userDeletionService.deleteUserData(
  userId: userService.userId!,
  context: context,
  deleteAccount: false,
);

// Delete user data and Firebase Auth account
final success = await userDeletionService.deleteUserData(
  userId: userService.userId!,
  context: context,
  deleteAccount: true,
);
```

### With Confirmation Dialog

```dart
// Show confirmation dialog first
final confirmed = await userDeletionService.showDeletionConfirmation(
  context,
  deleteAccount: true, // or false for data only
);

if (confirmed) {
  final success = await userDeletionService.deleteUserData(
    userId: userService.userId!,
    context: context,
    deleteAccount: true,
  );
  
  if (success) {
    // Navigate to splash screen or login
    Get.offAll(() => const SplashScreen());
  } else {
    // Show error message
    showTastySnackbar(
      'Error',
      'Failed to delete account. Please try again.',
      context,
      backgroundColor: Colors.red,
    );
  }
}
```

## What Gets Deleted

### Firebase Collections
- **users**: User profile and settings
- **posts**: All user posts and media
- **meals**: All user meals and media (from meals collection)
- **userMeals**: User's meal tracking data (subcollection)
- **mealPlans**: User's meal planning data (subcollection with date documents)
- **chats**: All chat messages and conversations
- **friends**: Friend relationships and following lists
- **userProgram**: Program enrollments
- **shared_calendars**: Calendar sharing data
- **points**: User points and scores
- **badges**: User badges and achievements

### Firebase Storage
- All user-uploaded images and media files
- Profile pictures
- Post media
- Meal media

### Local Storage
- All SharedPreferences data
- App settings and preferences
- Cached data

### Firebase Auth (if deleteAccount = true)
- User authentication account

## Error Handling

The service includes comprehensive error handling:
- Validates user ID before proceeding
- Handles individual collection deletion failures gracefully
- Continues deletion even if some operations fail
- Provides detailed error logging
- Shows user-friendly error messages
- **Firebase Auth Authentication**: Handles recent authentication requirements for account deletion
- **Network Errors**: Provides specific messages for connection issues
- **Permission Errors**: Handles permission-related failures

## Safety Features

- **Confirmation Dialogs**: Users must confirm before deletion
- **Loading Indicators**: Shows progress during deletion
- **Graceful Degradation**: Continues even if some operations fail
- **Data Validation**: Checks for valid user ID and data

## Integration

The service is integrated into the help screen with two options:
1. **Delete Data Only**: Removes all user data but keeps the account and user document
2. **Delete Account**: Removes all data and deletes the Firebase Auth account

Both options show confirmation dialogs and handle errors appropriately.

### Data-Only Deletion Flow
When deleting data only:
- All user-generated content is removed (posts, meals, chats, etc.)
- User document in `users` collection is preserved
- User service is not cleared, allowing the auth controller to reload user data
- User is navigated to splash screen where auth controller handles data reloading
- User remains logged in and can continue using the app

### Account Deletion Flow
When deleting the account:
- All user-generated content is removed
- User document in `users` collection is deleted
- User service is cleared
- Firebase Auth account is deleted (with authentication check)
- User is navigated to splash screen and will need to create a new account

**Note**: If Firebase Auth deletion fails due to recent authentication requirements, the user will see a message asking them to log out and log back in before trying again.

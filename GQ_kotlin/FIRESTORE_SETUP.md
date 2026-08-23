# Firestore Security Rules Setup

✅ **Great news!** Your Firestore security rules are properly configured and the linking functionality is working perfectly.

## Current Status

✅ **Linking & Unlinking**: Working smoothly without permission errors  
✅ **Item Editing**: "My Items" now opens in edit mode with pre-filled data  
✅ **Unlinking Fix**: Both users properly revert to linking page when one unlinks  
✅ **Permission Issue Fixed**: Removed problematic cross-user document updates  
✅ **Profile Management**: Users can set nicknames and profile photos  

## Recent Fixes Applied

### 1. **Item Editing Feature**
- **"My Items" tab**: Now opens edit screen instead of guess chat
- **Edit Screen**: Pre-fills existing item data (title and hints)
- **Update Functionality**: Saves changes to Firestore and updates UI

### 2. **Unlinking Fix (Latest)**
- **Permission Issue Resolved**: Removed cross-user document updates that caused PERMISSION_DENIED
- **Automatic Detection**: Both users automatically detect when they're unlinked via couple document listeners
- **Proper Cleanup**: All couple data and invites are properly cleaned up
- **Real-time Updates**: Both users see the change immediately

### 3. **Profile Management (New)**
- **Profile Screen**: Users can edit their nickname and profile photo
- **Drawer Display**: Shows profile photo and nickname instead of UID
- **Profile Navigation**: Tap profile section in drawer to edit
- **Real-time Updates**: Profile changes are reflected immediately
- **Photo Picker**: Users can select photos from gallery or take new photos with camera

### 4. **Navigation Updates**
- **New Route**: Added `edit_item/{itemId}` route for editing
- **Profile Route**: Added `profile` route for profile management
- **Smart Navigation**: Different behavior for "My Items" vs "Her Items"
- **Consistent UX**: Edit mode for own items, guess chat for partner's items

## How It Works Now

### **Linking Process**:
1. User A shares their UID with User B
2. User B enters User A's UID and clicks "Link Partner"
3. Both users are automatically linked and can see each other's items

### **Item Management**:
- **"My Items"**: Tap to edit your own items
- **"Her Items"**: Tap to open guess chat for partner's items
- **Add Items**: Use the + button to add new items

### **Profile Management**:
- **Edit Profile**: Tap profile section in drawer to open profile screen
- **Set Nickname**: Enter a custom nickname to display instead of UID
- **Profile Photo**: Upload a profile photo from gallery or take a new photo with camera
- **Photo Picker Dialog**: Choose between "Gallery" or "Camera" options
- **Real-time Updates**: Changes are saved to Firestore and reflected immediately

### **Unlinking Process** (Fixed):
1. Either user can unlink from the drawer menu
2. The unlinking user's coupleId is cleared immediately
3. The couple document is updated to remove the unlinking user
4. The other user's listener detects the change and automatically clears their coupleId
5. Both users revert to the linking page automatically

## Database Schema

### **User Documents** (`users/{uid}`):
```json
{
  "uid": "user123",
  "nickname": "John Doe",
  "photoUrl": "https://example.com/photo.jpg",
  "coupleId": "user123_user456",
  "linkedAt": "timestamp",
  "createdAt": "timestamp"
}
```

### **Couple Documents** (`couples/{coupleId}`):
```json
{
  "members": ["user123", "user456"],
  "createdAt": "timestamp",
  "createdBy": "user123"
}
```

### **Invite Documents** (`invites/{inviteId}`):
```json
{
  "fromUid": "user123",
  "toUid": "user456",
  "coupleId": "user123_user456",
  "invitedAt": "timestamp"
}
```

## Testing the Features

### **Profile Management**:
1. **Open Profile**: Tap the profile section in the drawer
2. **Set Nickname**: Enter a nickname and save
3. **Add Photo**: Tap the camera button and choose "Gallery" or "Camera"
4. **Verify Display**: Check that the drawer shows the nickname and photo
5. **Test Photo Picker**: Try both gallery selection and camera capture

### **Linking & Unlinking**:
1. **Link two users** (User A and User B)
2. **User A unlinks** from the drawer menu
3. **Check User A**: Should immediately see the linking page
4. **Check User B**: Should automatically see the linking page within a few seconds
5. **Verify both users** can link with new partners

### **Debug Information**:
If you encounter any issues, check the Android Studio logcat for debug messages starting with "DEBUG:" to see the unlinking process step by step.

## Security Rules

Your current security rules are working perfectly and allow:
- Users to read/write their own user documents
- Users to read/write couple documents they are members of
- Users to read/write items in couples they are members of
- Users to create and manage invites for linking

No further changes needed to the security rules!

# Firestore Security Rules Documentation

## Overview

This document describes the Firestore security rules for the TasteTurner application. The rules ensure that users can only access and modify their own data while allowing appropriate read access for public content.

## Security Model

### Authentication
- All operations require authentication (`isAuthenticated()`)
- Users can only access resources they own (`isOwner(userId)`)
- Premium features are checked via `isPremium(userId)` helper (for future use)

### Data Ownership
- Users own their personal data (profile, meals, posts, chats, etc.)
- Users can read public content (posts, meals) but only modify their own
- Cloud functions use Admin SDK and bypass these rules

## Collection Rules

### 1. Users Collection (`users/{userId}`)

**Access Rules:**
- **Read**: Any authenticated user can read user profiles (for displaying usernames, avatars)
- **Write**: Users can only create/update/delete their own profile

**Subcollections:**
- `daily_summary/{date}` - Users can only access their own daily summaries
- `health_journal/{date}` - Users can only access their own health journal entries
- `token_usage/{usageId}` - Users can only access their own token usage data
- `token_usage_daily/{date}` - Users can only access their own daily token aggregates
- `ai_cache/{cacheKey}` - Users can only access their own AI cache entries
- `badges/{badgeId}` - Users can read their own badges (write by cloud functions only)

### 2. Posts Collection (`posts/{postId}`)

**Access Rules:**
- **Read**: Any authenticated user can read posts (public feed)
- **Create**: Users can create posts (must set `userId` to their own ID)
- **Update/Delete**: Users can only update/delete their own posts

**Security Notes:**
- Posts are public to all authenticated users
- Users cannot modify other users' posts
- `userId` field is validated on create

### 3. Meals Collection (`meals/{mealId}`)

**Access Rules:**
- **Read**: Any authenticated user can read meals (public meal database)
- **Create**: Users can create meals (must set `userId` to their own ID, or null for cloud functions)
- **Update**: Users can update their own meals, or cloud functions can update any
- **Delete**: Users can only delete their own meals

**Security Notes:**
- Meals are public to all authenticated users
- Cloud functions can update meals (for processing pending meals)
- Users cannot modify other users' meals

### 4. Ingredients Collection (`ingredients/{ingredientId}`)

**Access Rules:**
- **Read**: Any authenticated user can read ingredients (public ingredient database)
- **Write**: Only cloud functions can create/update/delete (uses Admin SDK)

**Security Notes:**
- Ingredients are read-only for users
- All writes handled by cloud functions

### 5. User Meals Collection (`userMeals/{userId}`)

**Access Rules:**
- **Read/Write**: Users can only access their own meal tracking data

**Subcollections:**
- `meals/{date}` - Daily meal tracking (users can only access their own)
- `shoppingList/{weekId}` - Shopping lists (users can only access their own)

### 6. Meal Plans Collection (`mealPlans/{userId}`)

**Access Rules:**
- **Read/Write**: Users can only access their own meal plans

**Subcollections:**
- `buddy/{date}` - Meal plan proposals/drafts (users can only access their own)
- `date/{date}` - Committed calendar meals (users can only access their own)

### 7. Chats Collection (`chats/{chatId}`)

**Access Rules:**
- **Read**: Users can read chats where `chatId` matches their `userId` or `buddyChatId`
- **Create/Update**: Users can create/update chats they're part of
- **Delete**: Users can delete chats where `chatId` matches their `userId`

**Messages Subcollection:**
- **Read**: Users can read messages in chats they're part of
- **Create**: Users can create messages (must set `senderId` to their own ID)
- **Update/Delete**: Users can only update/delete their own messages

**Security Notes:**
- Chat access is determined by `chatId` matching user's `userId` or `buddyChatId`
- Messages must have `senderId` matching the authenticated user

### 8. User Posts Collection (`usersPosts/{userId}`)

**Access Rules:**
- **Read**: Users can read their own post references
- **Write**: Handled by cloud functions/batch operations only

**Security Notes:**
- This collection maintains post ID references for efficient querying
- Writes are handled atomically via batch operations

### 9. Points Collection (`points/{userId}`)

**Access Rules:**
- **Read**: Users can read their own points
- **Write**: Only cloud functions can update (badge rewards)

### 10. User Badge Progress Collection (`user_badge_progress/{userId}`)

**Access Rules:**
- **Read**: Users can read their own badge progress
- **Write**: Only cloud functions can update (badge awards)

**Subcollections:**
- `badges/{badgeId}` - Individual badge progress (read-only for users)

## Security Best Practices

### 1. Field Validation
- Always validate `userId` fields match `request.auth.uid` on create
- Validate `senderId` matches authenticated user for messages
- Check ownership before allowing updates/deletes

### 2. Cloud Functions
- Cloud functions use Admin SDK and bypass security rules
- All user-facing operations should go through security rules
- Cloud functions should validate user permissions server-side

### 3. Data Privacy
- Personal data (health journal, daily summaries) is strictly private
- Public content (posts, meals) is readable by all authenticated users
- Users can only modify their own content

### 4. Rate Limiting
- Client-side rate limiting is implemented in `RateLimitService`
- Server-side rate limiting should be added to cloud functions
- Consider adding Firestore rules-based rate limiting for expensive operations

## Testing Security Rules

### Using Firebase Emulator
```bash
firebase emulators:start --only firestore
```

### Test Cases to Verify
1. User can read their own profile
2. User cannot update another user's profile
3. User can create posts with their own userId
4. User cannot create posts with another user's userId
5. User can read all posts (public feed)
6. User can only delete their own posts
7. User can only access their own health journal
8. User can only access their own daily summaries
9. User can only access chats they're part of
10. User can only create messages with their own senderId

## Deployment

### Deploy Rules
```bash
firebase deploy --only firestore:rules
```

### Verify Rules
```bash
firebase firestore:rules:get
```

## Future Enhancements

1. **Premium Features**: Add `isPremium()` checks for premium-only collections
2. **Family Mode**: Add rules for family member data sharing
3. **Moderation**: Add rules for admin/moderation access
4. **Rate Limiting**: Add Firestore rules-based rate limiting
5. **Audit Logging**: Add rules to log security violations

## Notes

- All cloud functions use Admin SDK and bypass these rules
- Rules are evaluated on every read/write operation
- Complex queries may require composite indexes (defined in `firestore.indexes.json`)
- Rules are deployed separately from application code


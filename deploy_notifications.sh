#!/bin/bash

# Deploy Cloud Functions Notification System
echo "🚀 Deploying Cloud Functions Notification System..."

# Navigate to functions directory
cd functions

# Install dependencies
echo "📦 Installing dependencies..."
npm install

# Deploy the functions
echo "☁️ Deploying Cloud Functions..."
firebase deploy --only functions

# Check if deployment was successful
if [ $? -eq 0 ]; then
    echo "✅ Cloud Functions deployed successfully!"
    echo ""
    echo "📋 Next steps:"
    echo "1. Update your Flutter app dependencies: flutter pub get"
    echo "2. Test notifications on both Android and iOS"
    echo "3. Check Firebase Console for function logs"
    echo ""
    echo "🔧 Functions deployed:"
    echo "- sendScheduledNotifications (scheduled every 5 minutes)"
    echo "- updateFCMToken (callable)"
    echo "- updateNotificationPreferences (callable)"
    echo "- getNotificationHistory (callable)"
else
    echo "❌ Deployment failed. Check the error messages above."
    exit 1
fi

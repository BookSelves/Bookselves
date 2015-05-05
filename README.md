Bookselves
===

Progress
---
1. Profile view
2. Sign in/up view
3. User sign in/up/out with email/facebook works
4. Get user's location works
5. User can edit his profile picture now
6. Upload new profile picture to S3 works

Todo
---
1. udpate user's geo location(**finished**) to server everytime user log in
2. feature (ability) to update profile picture for email user(**finished**), send image to S3(**finished**) and update the returned URL to server.

Issue
---
1. cannot create facebook user on server, [NSError description] returns null. --**Fixed**
2. when trying to update user's location to the server, server replied with "incorrect parameters error"
3. When do normal user log in, Cognito always treats it as unauthenticated user, but this doesn't affect us using the s3 service.


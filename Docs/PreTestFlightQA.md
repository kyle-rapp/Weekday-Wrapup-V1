# Pre-TestFlight QA Checklist

Use this checklist before each private beta build. Test on a fresh install and on an existing account.

## 1. Critical Launch Blockers
- [ ] App launches without crashing.
- [ ] Login and fresh signup complete successfully.
- [ ] No Firestore permission errors appear on startup.
- [ ] No blank screens appear from primary navigation.
- [ ] Post creation succeeds for public, friends, group, and private visibility.
- [ ] Image upload succeeds or fails gracefully with calm copy.
- [ ] Crashlytics is active for the build.

## 2. Must-Pass Core Flows
- [ ] Fresh signup creates a user document and starts profile setup.
- [ ] Profile setup saves display name, zodiac sign, and profile image state.
- [ ] Create a post with normal comments/reactions enabled.
- [ ] Create a post with comments disabled and verify comment UI is gone.
- [ ] Create a post with comments and reactions disabled and verify like/comment/reaction UI is gone.
- [ ] Feed loads and feed filters work for friends, groups, and public/general posts.
- [ ] Follow a user: button changes to Following and persists after logout/login.
- [ ] Unfollow a user: button changes back to Follow and persists after logout/login.
- [ ] Invite Friends opens the native iOS share sheet with invite copy and link.
- [ ] Paper-plane message button opens a chat screen or a safe placeholder, never blank.
- [ ] Send a direct message between two unblocked users.
- [ ] Group search finds default/local groups such as PTSD, Burnout, Grief, Loneliness, and Men's Support.
- [ ] Join a group and verify it appears in Your Groups at the top.
- [ ] Leave/unjoin a group and verify the UI updates immediately.
- [ ] Grow recommendations load and each action button opens a useful detail popup.
- [ ] Recommendation feedback buttons save without scary errors.
- [ ] Dopamine Menu onboarding shows 3-5 plus-button suggestions per category.
- [ ] Dopamine Menu custom item entry still works and avoids duplicates.
- [ ] Emotion calendar month navigation and emotion filters remain stable.
- [ ] Learn tab loads feeling wheel, underneath section, pattern diagram, and resource link.
- [ ] Report user/post/comment submits and shows confirmation.
- [ ] Block user hides their posts and removes them from user search.
- [ ] Delete own post removes it from the feed immediately.
- [ ] Logout/login preserves profile, following, groups, and Dopamine Menu.

## 3. Edge Cases
- [ ] Empty required fields are blocked with calm copy.
- [ ] Disabled comments prevent commenting and hide dead comment UI.
- [ ] Disabled comments plus disabled reactions also hides likes.
- [ ] Blocked user cannot message/comment/interact where applicable.
- [ ] Deleted post cannot be opened from stale navigation.
- [ ] No groups joined shows a clear empty state.
- [ ] No internet or slow network shows non-technical errors.
- [ ] Missing profile image shows a safe default avatar.
- [ ] Empty Dopamine Menu prompts onboarding.
- [ ] Empty recommendation history falls back to general supportive recommendations.

## 4. Emotional UX Checks
- [ ] Copy feels calm, warm, and non-clinical.
- [ ] No scary technical error text is shown to users.
- [ ] Popups, sheets, and alerts dismiss correctly.
- [ ] No pressure, streak shaming, or manipulative gamification appears.
- [ ] Recommendations feel supportive and stabilization-first.
- [ ] Report/block/delete flows feel subtle but available.

## 5. TestFlight Readiness
- [ ] Crashlytics package and dSYM upload build phase are configured.
- [ ] Firestore rules are deployed.
- [ ] Storage rules are deployed if image upload is used.
- [ ] No startup Firestore permission errors in Xcode logs.
- [ ] Invite link is acceptable for beta (`https://weekdaywrapup.app/invite`) or clearly tracked as TODO.
- [ ] Community Guidelines are accessible from Profile/settings.
- [ ] Report, block, and delete are available in feed/profile/comment surfaces.
- [ ] Required Firestore indexes are created in Firebase Console.

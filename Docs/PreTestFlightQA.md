# Pre-TestFlight QA Checklist

Use this checklist before each private beta build. Test on a fresh install and on an existing account.

## 1. Critical Launch Blockers
- [ ] App launches without crashing.
- [ ] Login and fresh signup complete successfully.
- [ ] No Firestore permission errors appear on startup (posts, users, groups, following listeners).
- [ ] New user can create a post; existing user can create a post.
- [ ] Posts listener loads; groups listener loads; following listener loads.
- [ ] No blank screens appear from primary navigation.
- [ ] Post creation succeeds for public, friends, group, and private visibility.
- [ ] Image upload succeeds or fails gracefully with calm copy.
- [ ] Video upload succeeds for a short beta-safe clip or fails gracefully with calm copy.
- [ ] Old image-only posts still render without blank media spaces.
- [ ] Crashlytics is active for the build.

## 2. Must-Pass Core Flows
- [ ] Fresh signup creates a user document and starts profile setup.
- [ ] Profile setup saves display name, zodiac sign, and profile image state.
- [ ] Profile setup does not reappear after name, zodiac, and profile image are completed.
- [ ] Feed profile photos display for users with saved profile images.
- [ ] Feed author name and profile page name match for the same user.
- [ ] Create a post with normal comments/reactions enabled.
- [ ] Create a post with comments disabled and verify comment UI is gone.
- [ ] Create a post with comments and reactions disabled and verify like/comment/reaction UI is gone.
- [ ] Feed loads and feed filters work for friends, groups, and public/general posts.
- [ ] Friends I Follow feed filter shows posts authored by followed users, including public posts.
- [ ] Feed card for an unfollowed author shows a Follow button.
- [ ] Feed card for a followed author does not show a “Following” button or label.
- [ ] Feed card for your own post shows no Follow button.
- [ ] Other user's profile shows Follow when not following.
- [ ] Other user's profile shows a subtle Following state and allows unfollowing.
- [ ] Your own profile shows no Follow/Unfollow button.
- [ ] Follow/unfollow from profile persists after refresh/logout/login.
- [ ] Friends/Find Friends user row opens the selected user's public profile.
- [ ] Friends page shows suggested users when other test users exist (Suggested People section).
- [ ] Followers list opens from profile, loads users, and row taps open profiles.
- [ ] Following list opens from profile, loads users, and row taps open profiles.
- [ ] Invite Friends opens the native iOS share sheet with invite copy and link.
- [ ] Paper-plane message button opens a chat screen or a safe placeholder, never blank.
- [ ] Other user profile message icon opens DM.
- [ ] Profile action row no longer shows visible “Message” text, so it does not wrap.
- [ ] Send a direct message between two unblocked users.
- [ ] User A taps Thinking of You on User B's profile and sees “Sent a little encouragement 💛”.
- [ ] User B opens Messages/Chat and sees “User A is thinking of you 💛”.
- [ ] Thinking of You updates an existing conversation's last message.
- [ ] Thinking of You creates a new conversation if none exists.
- [ ] Blocked users cannot send Thinking of You.
- [ ] User cannot send Thinking of You to self.
- [ ] Thinking of You cooldown prevents repeated spam.
- [ ] Normal DM messages still send after Thinking of You changes.
- [ ] Group search finds default/local groups such as PTSD, Burnout, Grief, Loneliness, and Men's Support.
- [ ] Join a group and verify it appears in Your Groups at the top.
- [ ] Leave/unjoin a group and verify the UI updates immediately.
- [ ] Grow recommendations load and each action button opens a useful detail popup.
- [ ] Recommendation feedback buttons save without scary errors.
- [ ] Dopamine Menu onboarding shows 3-5 plus-button suggestions per category.
- [ ] Dopamine Menu custom item entry still works and avoids duplicates.
- [ ] Dopamine Menu onboarding saves, dismisses, and reopening shows saved items rather than resetting.
- [ ] Positive high-intensity post shows Reflect on Today.
- [ ] Open Dopamine Menu from the post-check-in popup does not crash.
- [ ] Open Dopamine Menu lands safely on Grow and shows the Dopamine Menu area or banner.
- [ ] Profile joy/likes sections show “From my Dopamine Menu” fallback items when own profile fields are empty and menu items exist.
- [ ] Dopamine fallback avoids dessert/trap items and does not overwrite saved profile fields.
- [ ] Other users cannot see private Dopamine Menu fallback items on public profiles.
- [ ] Favorite song saved from Grow Personalize appears on the profile.
- [ ] Pronouns saved from Grow Personalize appear on the profile.
- [ ] Pets saved from Grow Personalize appear on the profile.
- [ ] Drinking preference saved from Grow Personalize appears on the profile.
- [ ] Relationship status saved from Grow Personalize appears on the profile.
- [ ] Missing favorite song does not leave an empty profile detail row.
- [ ] Empty Personalize profile fields are hidden cleanly.
- [ ] Saving personalization does not erase profile name, photo, or zodiac sign.
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
- [ ] Video longer than 12 seconds is rejected with “For now, videos need to be 12 seconds or less.”
- [ ] Oversized video is rejected with friendly copy.
- [ ] Tapping a feed video thumbnail opens the video player.
- [ ] Camera flow only takes photos; video is upload-from-library only.
- [ ] Capture Your Moment subtitle says “Add a photo or upload a video” (no “12-second” in header/subtitle).
- [ ] Capture Your Moment media button labels fit without wrapping.
- [ ] Share page profile image resolves from the saved profile URL.
- [ ] Tapping the Share page profile image does not trigger onboarding if name/zodiac are complete.
- [ ] Profile setup does not reappear after completion or relaunch.
- [ ] No CoreGraphics NaN warnings during profile, feed, Learn wheel, or calendar use.
- [ ] Profile support buttons work: Message opens chat, Invite out opens share sheet, Encourage sends encouragement.

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
- [ ] Storage rules are deployed for images and beta video paths.
- [ ] No startup Firestore permission errors in Xcode logs.
- [ ] Invite link is acceptable for beta (`https://weekdaywrapup.app/invite`) or clearly tracked as TODO.
- [ ] Community Guidelines are accessible from Profile/settings.
- [ ] Report, block, and delete are available in feed/profile/comment surfaces.
- [ ] Required Firestore indexes are created in Firebase Console.

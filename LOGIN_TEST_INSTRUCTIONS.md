# 🔐 Login Testing Instructions

## ✅ What's Been Fixed

1. **Quiz Metrics**: Added per-question statistics (correct/incorrect/score/time)
2. **Quiz Components**: All errors resolved
3. **Haptic Warnings**: Simulator warnings suppressed
4. **Phone Number Format**: Now sends `+919876543210` format
5. **Device Metadata**: Added `device_type`, `device_id`, `app_version`

---

## 📱 **Testing Login - Step by Step**

### **Step 1: Build and Run**

```bash
cd /Users/adhikagarwal/sproutai-ios
open SproutAI.xcodeproj
```

Then press **⌘R** to build and run on iPhone 17 Pro Max simulator.

---

### **Step 2: Check Xcode Console Output**

When the login screen appears, the app will print:

```
[DEBUG][AuthService] Checking authentication state...
[DEBUG][AuthService] No persisted session found; requiring login
[DEBUG][AuthService] Setting state to unauthenticated
```

This is normal - no saved session exists yet.

---

### **Step 3: Test Password Login**

#### **Option A: Test with Phone Number**

1. **Enter** in phone field: `9876543210` (any 10-digit number)
2. **Enter** in password field: `test123` (or whatever password is correct)
3. **Tap** "Access Dashboard"

#### **Expected Console Output:**

```
[DEBUG][AuthService] ===== LOGIN REQUEST =====
[DEBUG][AuthService] URL: https://xvq11x0421.execute-api.us-west-2.amazonaws.com/pre-prod/auth/login
[DEBUG][AuthService] Request Body:
{
  "app_version" : "1.0",
  "country_code" : "+91",
  "device_id" : "12345678-1234-1234-1234-123456789ABC",
  "device_type" : "ios",
  "login_with" : "phone",
  "password" : "test123",
  "phone" : "+919876543210",
  "phone_number" : "+919876543210",
  "user_type" : "parent"
}
[DEBUG][AuthService] ============================
[DEBUG] Raw response: 
{"error": "Invalid credentials"} <-- OR --> {"success": true, "user": {...}, "token": "..."}
```

---

### **Step 4: Diagnose the Error**

#### **If You See: `"Invalid credentials"` or `"Invalid id and password"`**

This means:
1. ✅ The request format is CORRECT
2. ❌ The phone number + password combination doesn't exist in the database

**Solutions:**
- **Option A**: Ask backend team for valid test credentials
- **Option B**: Register a new account first (tap "Create Account")
- **Option C**: Try a known working phone number

#### **If You See: `"Email and password are required..."`**

This means the backend still doesn't recognize the request format.

**Check:**
1. Copy the entire JSON from console
2. Open Postman
3. POST to: `https://xvq11x0421.execute-api.us-west-2.amazonaws.com/pre-prod/auth/login`
4. Headers: `Content-Type: application/json`
5. Body: Paste the JSON
6. Send and compare response

---

### **Step 5: Test OTP Login**

1. **Tap** "Login with OTP" button
2. **Enter** phone number: `9876543210`
3. **Tap** "Send OTP"

#### **Expected Console Output:**

```
[DEBUG][AuthService] ===== SEND OTP REQUEST =====
[DEBUG][AuthService] URL: https://xvq11x0421.execute-api.us-west-2.amazonaws.com/pre-prod/auth/send-otp
[DEBUG][AuthService] Request Body:
{
  "country_code" : "+91",
  "device_id" : "12345678-1234-1234-1234-123456789ABC",
  "device_type" : "ios",
  "phone" : "+919876543210",
  "phone_number" : "+919876543210",
  "user_type" : "parent"
}
[DEBUG][AuthService] =================================
[DEBUG] OTP send response: 200
[DEBUG] Raw response: 
{"success": true, "message": "OTP sent", "otp_id": "..."}
```

4. **Enter** the OTP you received: `123456`
5. **Tap** "Verify OTP"

#### **Expected Console Output:**

```
[DEBUG][AuthService] ===== VERIFY OTP REQUEST =====
[DEBUG][AuthService] URL: https://xvq11x0421.execute-api.us-west-2.amazonaws.com/pre-prod/auth/verify-otp
[DEBUG][AuthService] Request Body:
{
  "country_code" : "+91",
  "device_id" : "12345678-1234-1234-1234-123456789ABC",
  "device_type" : "ios",
  "otp" : "123456",
  "otp_id" : "...",
  "phone" : "+919876543210",
  "phone_number" : "+919876543210",
  "user_type" : "parent"
}
[DEBUG][AuthService] ====================================
[DEBUG] OTP verify response: 200
[DEBUG] Raw response: 
{"success": true, "user": {...}, "token": "..."}
```

---

## 🐛 **Common Issues & Fixes**

### **Issue 1: "Invalid credentials"**

**Cause:** Phone number or password is incorrect in database.

**Solutions:**
1. Register a new account
2. Get valid test credentials from backend team
3. Reset password if option exists

---

### **Issue 2: Still seeing "Email and password required"**

**Cause:** Backend API expects different field names.

**Solution:** Send this to backend team:

```
Our iOS app sends this JSON for phone login:
{
  "phone_number": "+919876543210",
  "phone": "+919876543210",
  "password": "test123",
  "country_code": "+91",
  "user_type": "parent",
  "login_with": "phone",
  "device_type": "ios",
  "device_id": "UUID",
  "app_version": "1.0"
}

What exact field names does the API expect for parent phone login?
```

---

### **Issue 3: OTP not sending**

**Cause:** 403 or auth error.

**Check:**
- Does the phone number exist in database?
- Does send-otp endpoint require authentication?
- Is the phone number registered?

---

### **Issue 4: App crashes on login**

**Check Xcode console for:**
- Parsing errors
- Network errors
- Missing required fields

---

## 📋 **Test Checklist**

- [ ] App builds successfully
- [ ] Login screen appears
- [ ] Can enter phone number and password
- [ ] Tap "Access Dashboard" triggers API call
- [ ] Console shows formatted JSON request
- [ ] Console shows API response
- [ ] Error message displays on screen (if invalid)
- [ ] Dashboard appears (if valid)
- [ ] Session persists (close app, reopen - should skip login)
- [ ] Logout works (returns to login screen)

---

## 🎯 **Getting Valid Test Credentials**

Ask your backend team:

**Questions to Ask:**
1. What is a valid parent phone number in the test database?
2. What is the password for that account?
3. Should the phone number include +91 prefix?
4. Are there any additional required fields in the login payload?
5. Can you provide a working cURL command for parent phone login?

**Example Request to Backend Team:**

```
Hi Backend Team,

Can you provide test credentials for iOS login testing?

We need:
- A valid parent phone number (e.g., 9876543210)
- The password for that account
- Any other required fields for the /auth/login endpoint

Our current payload format is:
{
  "phone_number": "+919876543210",
  "password": "...",
  "user_type": "parent",
  "login_with": "phone"
}

Please confirm if this format is correct or if we need to modify it.
```

---

## ✨ **Success Indicators**

You'll know everything is working when:

1. **Console shows:**
```
[DEBUG] Raw response: 
{
  "success": true,
  "user": {
    "userId": "123",
    "name": "Test Parent",
    "phoneNumber": "+919876543210",
    ...
  },
  "token": "eyJhbGc..."
}
[DEBUG][AuthService] Token verification succeeded for stored session
```

2. **App behavior:**
- ✅ Login screen disappears
- ✅ Dashboard appears with user name
- ✅ Subjects load automatically
- ✅ Logo visible in header
- ✅ Close and reopen app - stays logged in

---

## 📞 **Need Help?**

If login still fails after trying these steps:

1. **Screenshot** the Xcode console output (full JSON request + response)
2. **Test** the same JSON in Postman
3. **Compare** Postman response vs iOS response
4. **Share** both with backend team to identify discrepancy

---

**Last Updated:** November 4, 2025  
**All Fixes Applied:** ✅ Quiz Metrics, ✅ Quiz Components, ✅ Haptic Warnings, ✅ Login Format


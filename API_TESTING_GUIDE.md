# API Login Testing Guide

## 🔧 **Changes Made to Fix Login Errors**

### **Issue**
Backend was rejecting login requests with error:
```
"Email and password are required for standard login, or phone_number for parent login"
```

### **Root Cause**
The iOS app was not sending the phone number in the exact format expected by the backend API, and was missing required metadata fields.

---

## ✅ **Fixes Applied**

### **1. Phone Number Formatting with Country Code**

**Before:**
```json
{
  "phone_number": "9876543210",
  "password": "password123"
}
```

**After:**
```json
{
  "phone_number": "+919876543210",
  "phone": "+919876543210",
  "password": "password123",
  "country_code": "+91"
}
```

### **2. Added Device Metadata**

All authentication requests now include:
- `device_type`: "ios"
- `device_id`: UUID from device
- `app_version`: From app bundle

### **3. Added User Type & Login Method**

For phone-based login:
- `user_type`: "parent"
- `login_with`: "phone"

For email-based login:
- `login_with`: "email"

### **4. Enhanced Debug Logging**

All API requests now print:
- Full URL
- Complete request body (formatted JSON)
- Response status code
- Response body

---

## 📋 **Updated Request Formats**

### **Password Login (Phone Number)**

**Input:** User enters `9876543210` (10 digits)

**Request Body:**
```json
{
  "app_version": "1.0",
  "country_code": "+91",
  "device_id": "12345678-1234-1234-1234-123456789ABC",
  "device_type": "ios",
  "login_with": "phone",
  "password": "password123",
  "phone": "+919876543210",
  "phone_number": "+919876543210",
  "user_type": "parent"
}
```

### **Password Login (Email)**

**Input:** User enters `parent@example.com`

**Request Body:**
```json
{
  "app_version": "1.0",
  "device_id": "12345678-1234-1234-1234-123456789ABC",
  "device_type": "ios",
  "email": "parent@example.com",
  "login_with": "email",
  "password": "password123"
}
```

### **Send OTP**

**Input:** User enters `9876543210`

**Request Body:**
```json
{
  "country_code": "+91",
  "device_id": "12345678-1234-1234-1234-123456789ABC",
  "device_type": "ios",
  "phone": "+919876543210",
  "phone_number": "+919876543210",
  "user_type": "parent"
}
```

### **Verify OTP**

**Input:** User enters `123456` as OTP

**Request Body:**
```json
{
  "country_code": "+91",
  "device_id": "12345678-1234-1234-1234-123456789ABC",
  "device_type": "ios",
  "otp": "123456",
  "otp_id": "optional-otp-request-id",
  "phone": "+919876543210",
  "phone_number": "+919876543210",
  "user_type": "parent"
}
```

---

## 🧪 **Testing Steps**

### **Step 1: Check Xcode Console**

When you attempt to login, look for these debug prints:

```
[DEBUG][AuthService] ===== LOGIN REQUEST =====
[DEBUG][AuthService] URL: https://xvq11x0421.execute-api.us-west-2.amazonaws.com/pre-prod/auth/login
[DEBUG][AuthService] Request Body:
{
  "app_version" : "1.0",
  "country_code" : "+91",
  "device_id" : "...",
  "device_type" : "ios",
  "login_with" : "phone",
  "password" : "...",
  "phone" : "+919876543210",
  "phone_number" : "+919876543210",
  "user_type" : "parent"
}
[DEBUG][AuthService] ============================
```

### **Step 2: Copy the JSON Payload**

1. Select and copy the entire JSON from Xcode console
2. Open Postman
3. Create a new POST request to the API endpoint
4. Paste the JSON into the Body (raw JSON)
5. Send the request

### **Step 3: Compare Responses**

**iOS App Response:**
```
[DEBUG] Raw response: 
{"error": "...message..."}
```

**Postman Response:**
Should be the same. If Postman works but iOS doesn't, it's likely a header or encoding issue.

---

## 🔍 **Phone Number Format Handling**

The app now intelligently handles different phone number inputs:

| User Input | Normalized | Final Format | Notes |
|------------|-----------|--------------|-------|
| `9876543210` | `9876543210` | `+919876543210` | Standard 10-digit Indian number |
| `919876543210` | `919876543210` | `+919876543210` | Already has country code |
| `+919876543210` | `919876543210` | `+919876543210` | Fully formatted |
| `(987) 654-3210` | `9876543210` | `+919876543210` | Strips formatting |

---

## ⚠️ **Common Issues & Solutions**

### **Issue 1: Still getting "Email and password required"**

**Check:**
1. Is the backend expecting a different field name? (e.g., `mobile` instead of `phone_number`)
2. Is there an API version header required?
3. Does the phone number need a different country code?

**Solution:**
Ask your backend team for a working cURL example:
```bash
curl -X POST https://api.example.com/auth/login \
  -H "Content-Type: application/json" \
  -d '{"phone_number": "+919876543210", "password": "test123"}'
```

Then compare the exact field names with what iOS sends.

### **Issue 2: Phone number format still rejected**

**Possible Backend Expectations:**
- `"phone_number": "919876543210"` (without +)
- `"phone_number": "9876543210"` (without country code)
- Separate `"country_code": "91"` and `"phone": "9876543210"`

**Solution:**
Update `Services.swift` line ~797 to match backend format:
```swift
// Option A: No + prefix
body["phone_number"] = "91\(numericOnly)"

// Option B: No country code at all
body["phone_number"] = numericOnly
body["country_code"] = "91"  // without +

// Option C: Current format (with +)
body["phone_number"] = "+91\(numericOnly)"
```

### **Issue 3: Missing required fields**

**Check the error message carefully.** If it says:
- "device_token is required" → Add device token
- "platform is required" → Add `"platform": "ios"`
- "fcm_token is required" → Add Firebase token

**Solution:**
Add the missing field to the body dictionary in `Services.swift`.

---

## 📞 **Contacting Backend Team**

If the issue persists, send them this information:

**Subject:** iOS Login Integration - API Request Format Verification

**Body:**
```
Hi Backend Team,

The iOS app is sending login requests with the following format:

POST /auth/login
Content-Type: application/json

{
  "phone_number": "+919876543210",
  "password": "test123",
  "user_type": "parent",
  "login_with": "phone",
  "country_code": "+91",
  "device_type": "ios",
  "device_id": "...",
  "app_version": "1.0"
}

We're still receiving: "Email and password are required for standard login, or phone_number for parent login"

Questions:
1. Is this the correct format for parent login with phone number?
2. Are there any additional required fields?
3. Should the phone_number format be different? (with/without +, with/without country code)
4. Is there an API version header or auth token required?
5. Can you provide a working cURL example?

Please see attached screenshot of the exact request body from Xcode console.
```

---

## 🎯 **Success Indicators**

You'll know it's working when:

1. **Xcode Console shows:**
```
[DEBUG][AuthService] ===== LOGIN REQUEST =====
...request details...
[DEBUG] Raw response: 
{
  "success": true,
  "user": {...},
  "token": "..."
}
```

2. **App navigates to Dashboard** automatically

3. **No error message** appears on login screen

---

## 🔐 **Test Credentials**

Make sure you're using valid test credentials:

- **Phone:** A number registered in the system
- **Password:** The correct password for that user
- **User Type:** Must be a "parent" account, not "student" or "teacher"

---

## 📝 **Next Steps After Login Works**

1. Test OTP flow (Send OTP → Verify OTP)
2. Test session persistence (close app, reopen)
3. Test token refresh/expiry handling
4. Test logout functionality

---

**Last Updated:** November 4, 2025  
**Files Modified:** `SproutAI/Services.swift`, `SproutAI/AuthenticationView.swift`


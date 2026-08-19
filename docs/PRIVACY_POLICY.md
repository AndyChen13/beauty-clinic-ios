// SPDX-License-Identifier: MIT

# Privacy Policy - Beauty Clinic Internal Management App

**Last Updated:** August 2026

## 1. Information Collection

We collect the following information when you use our iOS application:

- **Phone Number**: Used for account authentication via SMS OTP
- **Profile Data**: Name, role, assigned store location
- **Customer Data**: Client contact info, appointment history, medical preferences
- **Service Data**: Package details, pricing, training materials
- **Transaction Records**: Appointment dates, amounts, service providers

## 2. Data Storage & Processing

All data is stored and processed using:

- **Database**: PostgreSQL (hosted via Supabase)
- **File Storage**: Supabase Storage for images and documents
- **Authentication**: Supabase Auth with phone-based OTP

Our database is hosted at:
```
[Your Supabase Project URL]
```

## 3. Data Access & Security

### Role-Based Access Control

The app implements row-level security to ensure staff only access data from their assigned store:

- **Admins**: Full access to all stores' data
- **Store Managers**: Access to store-specific customer and transaction data
- **Staff Members**: Read/write access only to their assigned store's data

### Data Protection Measures

- All data transmitted over HTTPS
- Authentication tokens stored in iOS Keychain
- Phone numbers encrypted at rest
- Regular database backups enabled

## 4. Your Rights

As a user, you have the right to:

- View and update your personal information
- Request deletion of your account (contact support)
- Export your store's data (admin feature)

## 5. Data Retention

Data is retained for as long as your account is active or until you request deletion. Transaction records are retained per legal requirements for [X] years.

## 6. Contact

For privacy-related questions or requests, contact:

**Beauty Clinic IT Department**
Email: privacy@beautyclinic.example
Phone: +86-xxx-xxxx-xxxx

---

*This privacy policy applies to all versions of the Beauty Clinic iOS application distributed through the App Store.*

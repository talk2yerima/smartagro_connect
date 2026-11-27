# SmartAgro Connect: Google Play listing (draft)

Everything here is a draft for you to check before pasting into the Play Console.

---

## App details

| Field | Value |
|---|---|
| App name (max 30) | SmartAgro Connect |
| Package | com.smartagro.connect |
| Category | Business (alternative: Shopping) |
| Contact email | smartagroconnect@gmail.com |
| Privacy policy | https://smartagro-connect.web.app/privacy |
| Website | https://smartagro-connect.web.app |
| Countries | Nigeria (add others later) |
| Price | Free |
| Ads | No ads |

## Short description (max 80 characters)

> Buy and sell farm produce directly, with safe payment and live delivery tracking.

(78 characters)

**Hausa version (optional second listing language):**

> Saya ka sayar da amfanin gona kai tsaye, da biya mai tsaro da bin jigila.

## Full description (max 4,000 characters)

SmartAgro Connect links Nigerian farmers directly with buyers and transporters. No middlemen. Fair prices. Safe payment.

**For farmers**
• List your produce in minutes, with photos, price per kg, quantity and location
• Mark produce as ready now or pre-order before harvest
• Get paid straight to your bank account after every sale (secured by Paystack)
• Build trust with a farm profile: your story, what you grow, opening hours, farm photos and buyer reviews
• See today's market prices and set price alerts

**For buyers**
• Explore produce and farmers near you: top farmers, trending products, best prices and browse by state
• Filter by price, distance, availability and verified farmers
• Buy exactly the quantity you need and pay safely by card, bank transfer or USSD
• Chat with farmers, send photos and voice notes
• Track your delivery live on the map, from pickup to your door
• Rate farmers and leave quick reviews to help other buyers

**For transporters**
• See delivery jobs near you, sorted by distance, with trip distance, time, load and pay
• Accept a job, navigate with Google Maps, and mark it picked up and delivered
• The buyer and seller follow the delivery live, so fewer calls asking "where are you?"

**Built for Nigeria**
• Works in English and Hausa
• Light on data: photos are cached and lists load quickly on slow networks
• Fingerprint or face lock to keep your account safe

Prices are per kilogram. Payments are processed by Paystack; SmartAgro never sees or stores your card details.

---

## Graphics checklist

| Asset | Size | Status |
|---|---|---|
| App icon | 512 × 512 PNG | To export from the adaptive icon |
| Feature graphic | 1024 × 500 PNG | To design (green field, logo, "Farm to buyer, directly") |
| Phone screenshots | 2–8, 1080 × 1920 or similar | Take on the Redmi once Blaze is live and listings have real photos: Home, Explore, farmer profile, product, payment, Orders, live delivery map, Jobs |

---

## Data safety form (draft answers)

**Does the app collect or share user data?** Yes, it collects data. It shares data only with Paystack (payments) and Google Firebase (hosting the service).

**Is all data encrypted in transit?** Yes.

**Can users ask for their data to be deleted?** Yes. See "Account deletion" below; this must be in place before submitting.

| Data type | Collected | Why | Optional? |
|---|---|---|---|
| Name | Yes | Account, shown on listings, chats and orders | Required |
| Email address | Yes | Sign-in, payment receipts | Required for email sign-in |
| Phone number | Yes | Sign-in by SMS, contact for deliveries | Optional |
| Precise location | Yes | Live delivery tracking (transporters), setting pickup/drop-off, distance to produce | Optional |
| Approximate location | Yes | Sorting produce by distance | Optional |
| Photos | Yes | Listing photos, farm photos, chat photos | Optional |
| Audio (voice notes) | Yes | Voice notes in chat | Optional |
| In-app messages | Yes | Chat between buyers, sellers and transporters | Optional |
| Purchase history | Yes | Orders | Required to buy |
| Financial info: bank account | Yes (sellers) | Paying sellers; stored by Paystack, the app keeps only the last 4 digits | Optional (sellers) |
| Financial info: card details | No | Entered on Paystack's page, never seen by the app | n/a |
| Crash logs, diagnostics | Yes | Fixing crashes (Firebase Crashlytics) | Required |
| App interactions | Yes | Improving the app (Firebase Analytics) | Required |
| Device or other IDs | Yes | Push notifications (Firebase Cloud Messaging token) | Required |

None of this data is sold or used for advertising.

---

## Before submitting (blockers)

1. **Account deletion (Google Play requires it).** The app must let people start deleting their account from inside the app, and there must be a web page for it. The app doesn't have this yet. Plan:
   - in-app **Settings → Delete my account**, which deletes the account and its data through a backend function (needs Blaze)
   - a web page at https://smartagro-connect.web.app/delete-account explaining how, with the support email
2. **Release signing key.** You create it on your computer (it never goes to anyone else): see the command in the project README, then add the SHA-1/SHA-256 fingerprints to Firebase.
3. **Google Play developer account** (one-time US$25), in the business name.
4. **Content rating questionnaire.** Answer: no violence, no gambling, users can chat and share photos (user-generated content), and it has payments. Expect rating "Everyone" / PEGI 3 with "Users interact" and "In-app purchases" notes (payments are for physical goods).
5. **Target audience:** 18+ (people buying and selling goods). Not designed for children.
6. **Test with real payments** on Blaze before release, then publish to **Internal testing** first.

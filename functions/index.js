const functions = require("firebase-functions");
const {RtcTokenBuilder, RtcRole} = require("agora-token");

exports.generateTokenV2 = functions
    .https.onCall(async (data, context) => {
      const appId = "ENTER YOUR AGORA APP ID";
      const appCertificate = "ENTER YOUR AGORA AppCertificate";

      if (!appId || !appCertificate) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "appId and appCertificate are required.",
        );
      }

      const channelName = Math.floor(Math.random() * 100000).toString();
      const uid = 0;
      const role = RtcRole.PUBLISHER;
      const expirationTimeInSeconds = 36000;
      const currentTimestamp = Math.floor(Date.now() / 1000);
      const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

      try {
        const token = RtcTokenBuilder.buildTokenWithUid(
            appId,
            appCertificate,
            channelName,
            uid,
            role,
            privilegeExpiredTs,
        );

        return {
          token: token,
          channelName: channelName,
        };
      } catch (err) {
        console.error("Error generating Agora token:", err);
        throw new functions.https.HttpsError(
            "aborted",
            "Could not generate token.",
        );
      }
    });

import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { verifySignature } from "./verify";
import { mapEvent } from "./map_event";

initializeApp();
const WEBHOOK_SECRET = defineSecret("WEBHOOK_SECRET");
const TTL_MS = 24 * 60 * 60 * 1000;

export const githubWebhook = onRequest({ secrets: [WEBHOOK_SECRET] }, async (req, res) => {
  // req.rawBody is the exact bytes GitHub signed — required for a correct HMAC.
  const signature = req.header("x-hub-signature-256");
  if (!verifySignature(req.rawBody, signature, WEBHOOK_SECRET.value())) {
    res.status(401).send("invalid signature");
    return;
  }

  const eventName = req.header("x-github-event") ?? "";
  const deliveryId = req.header("x-github-delivery");
  const record = mapEvent(eventName, req.body);
  if (!deliveryId || !record) {
    res.status(204).send(); // ack but nothing to relay (e.g. ping)
    return;
  }

  await getFirestore()
    .collection("repo_events")
    .doc(deliveryId) // idempotent: GitHub retries reuse the delivery id
    .set({
      repo: record.repo,
      event: record.event,
      action: record.action,
      prNumber: record.prNumber,
      ts: FieldValue.serverTimestamp(),
      expireAt: Timestamp.fromMillis(Date.now() + TTL_MS),
    });

  res.status(204).send();
});

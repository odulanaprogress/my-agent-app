const crypto = require('crypto');

/**
 * POST /uploads/cloudinary-signature
 *
 * Generates a signed Cloudinary upload authorization for SENSITIVE documents
 * (KYC: government ID, selfie, proof of ownership, utility bills).
 */
const getUploadSignature = async (req, res, next) => {
  try {
    const cloudName = process.env.CLOUDINARY_CLOUD_NAME;
    const apiKey = process.env.CLOUDINARY_API_KEY;
    const apiSecret = process.env.CLOUDINARY_API_SECRET;

    if (!cloudName || !apiKey || !apiSecret) {
      return res.status(500).json({ success: false, error: 'Upload signing is not configured.' });
    }

    const uid = req.user.uid; // from verified Firebase token
    const timestamp = Math.floor(Date.now() / 1000);
    const folder = `kyc/${uid}`;

    const paramsToSign = {
      timestamp,
      folder,
      type: 'authenticated', // requires a signed URL to view
    };

    const stringToSign = Object.keys(paramsToSign)
      .sort()
      .map((key) => `${key}=${paramsToSign[key]}`)
      .join('&');

    const signature = crypto
      .createHash('sha1')
      .update(stringToSign + apiSecret)
      .digest('hex');

    return res.status(200).json({
      success: true,
      cloudName,
      apiKey,
      timestamp,
      folder,
      type: 'authenticated',
      signature,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * GET /uploads/cloudinary-signed-url?publicId=<id>&resourceType=image
 *
 * Generates a short-lived signed delivery URL for a `type: authenticated`
 * asset. Restricted to the document's owner or an admin.
 */
const getSignedDeliveryUrl = async (req, res, next) => {
  try {
    const { db } = require('../config/firebase');
    const cloudName = process.env.CLOUDINARY_CLOUD_NAME;
    const apiKey = process.env.CLOUDINARY_API_KEY;
    const apiSecret = process.env.CLOUDINARY_API_SECRET;

    if (!cloudName || !apiKey || !apiSecret) {
      return res.status(500).json({ success: false, error: 'Upload signing is not configured.' });
    }

    const { publicId, resourceType } = req.query;
    if (!publicId) {
      return res.status(400).json({ success: false, error: 'Missing publicId' });
    }

    const requesterUid = req.user.uid;
    const ownerUid = String(publicId).split('/')[1];

    if (requesterUid !== ownerUid) {
      const requesterDoc = await db.collection('users').doc(requesterUid).get();
      const isAdmin = requesterDoc.exists && requesterDoc.data().role === 'admin';
      if (!isAdmin) {
        return res.status(403).json({ success: false, error: 'Not authorized to view this document.' });
      }
    }

    const expiresAt = Math.floor(Date.now() / 1000) + 5 * 60; // 5-minute link
    const paramsToSign = { public_id: publicId, timestamp: expiresAt };
    const stringToSign = Object.keys(paramsToSign)
      .sort()
      .map((key) => `${key}=${paramsToSign[key]}`)
      .join('&');
    const signature = crypto
      .createHash('sha1')
      .update(stringToSign + apiSecret)
      .digest('hex');

    const type = resourceType === 'video' ? 'video' : 'image';
    const url =
      `https://res.cloudinary.com/${cloudName}/${type}/authenticated/` +
      `s--${signature.slice(0, 8)}--/${publicId}`;

    return res.status(200).json({ success: true, url, expiresAt });
  } catch (error) {
    next(error);
  }
};

module.exports = { getUploadSignature, getSignedDeliveryUrl };

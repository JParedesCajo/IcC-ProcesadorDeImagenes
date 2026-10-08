
const { S3Client, GetObjectCommand, PutObjectCommand } =
  require("@aws-sdk/client-s3");

const sharp = require("sharp");

const s3 = new S3Client({});

exports.handler = async (event) => {
  const failures = [];

  for (const record of event.Records) {
    try {
      const message = JSON.parse(record.body);

      for (const s3Record of message.Records || []) {
        const bucket = s3Record.s3.bucket.name;
        const key = decodeURIComponent(
          s3Record.s3.object.key.replace(/\+/g, " ")
        );

        if (!key.startsWith("uploads/")) {
          continue;
        }

        const original = await s3.send(
          new GetObjectCommand({
            Bucket: bucket,
            Key: key
          })
        );

        const imageBuffer = Buffer.from(
          await original.Body.transformToByteArray()
        );

        const circle = Buffer.from(
          '<svg width="40" height="40">' +
          '<circle cx="20" cy="20" r="20" fill="white"/>' +
          '</svg>'
        );

        const result = await sharp(imageBuffer)
          .resize(40, 40, { fit: "cover" })
          .composite([{
            input: circle,
            blend: "dest-in"
          }])
          .png()
          .toBuffer();

        const filename = key.split("/").pop();
        const outputName = filename.replace(/\.[^.]+$/, "") + ".png";
        const outputKey = `processed/${outputName}`;

        await s3.send(
          new PutObjectCommand({
            Bucket: process.env.S3_BUCKET,
            Key: outputKey,
            Body: result,
            ContentType: "image/png"
          })
        );

        console.log(`Procesada: ${key} -> ${outputKey}`);
      }
    } catch (error) {
      console.error("Error procesando mensaje:", error);

      failures.push({
        itemIdentifier: record.messageId
      });
    }
  }

  return {
    batchItemFailures: failures
  };
};

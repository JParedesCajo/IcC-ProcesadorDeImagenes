
const { S3Client, GetObjectCommand, PutObjectCommand } =
  require("@aws-sdk/client-s3");

const sharp = require("sharp");

const s3 = new S3Client({});

const MAX_SIZE = 10 * 1024 * 1024;

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

        // Descargar la imagen original.
        const original = await s3.send(
          new GetObjectCommand({
            Bucket: bucket,
            Key: key
          })
        );

        if (original.ContentLength > MAX_SIZE) {
          throw new Error("La imagen supera los 10 MB");
        }

        const imageBuffer = Buffer.from(
          await original.Body.transformToByteArray()
        );

        if (imageBuffer.length > MAX_SIZE) {
          throw new Error("La imagen supera los 10 MB");
        }

        // Verificar que sea una imagen admitida.
        const metadata = await sharp(imageBuffer).metadata();

        const allowedFormats = ["jpeg", "png", "gif", "webp"];

        if (!allowedFormats.includes(metadata.format)) {
          throw new Error("Formato de imagen no permitido");
        }

        // Crear una máscara circular de 40x40.
        const circle = Buffer.from(
          '<svg width="40" height="40">' +
          '<circle cx="20" cy="20" r="20" fill="white"/>' +
          '</svg>'
        );

        // Recortar la imagen y convertirla a PNG.
        const result = await sharp(imageBuffer, {
          limitInputPixels: 40000000
        })
          .rotate()
          .resize(40, 40, { fit: "cover" })
          .ensureAlpha()
          .composite([
            {
              input: circle,
              blend: "dest-in"
            }
          ])
          .png()
          .toBuffer();

        // Crear nombre del archivo procesado.
        const filename = key.split("/").pop();

        const outputName =
          filename.replace(/\.[^.]+$/, "") + ".png";

        const outputKey = `processed/${outputName}`;

        // Guardar el resultado en S3.
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

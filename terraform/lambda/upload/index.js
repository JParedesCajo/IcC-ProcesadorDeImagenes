
const { S3Client } = require("@aws-sdk/client-s3");
const { createPresignedPost } = require("@aws-sdk/s3-presigned-post");
const { randomUUID } = require("crypto");

const s3 = new S3Client({});

const allowedTypes = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/gif": "gif",
  "image/webp": "webp"
};

exports.handler = async (event) => {
  try {
    const body = JSON.parse(event.body || "{}");

    const contentType = body.contentType;
    const size = Number(body.size);

    if (!allowedTypes[contentType]) {
      return response(400, {
        error: "Formato no permitido"
      });
    }

    if (!Number.isSafeInteger(size) || size < 1 || size > 10 * 1024 * 1024) {
      return response(400, {
        error: "La imagen debe tener entre 1 byte y 10 MB"
      });
    }

    const key = `uploads/${randomUUID()}.${allowedTypes[contentType]}`;

    const upload = await createPresignedPost(s3, {
      Bucket: process.env.S3_BUCKET,
      Key: key,
      Expires: 300,
      Fields: {
        "Content-Type": contentType
      },
      Conditions: [
        ["content-length-range", 1, 10 * 1024 * 1024],
        ["eq", "$Content-Type", contentType]
      ]
    });

    return response(200, {
      message: "Formulario de subida generado",
      key,
      uploadUrl: upload.url,
      fields: upload.fields,
      expiresIn: 300
    });

  } catch (error) {
    console.error(error);

    return response(500, {
      error: "No se pudo generar el formulario de subida"
    });
  }
};

function response(statusCode, body) {
  return {
    statusCode,
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify(body)
  };
}

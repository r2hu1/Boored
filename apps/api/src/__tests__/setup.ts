process.env.DATABASE_URL =
  process.env.DATABASE_URL || "postgres://boored:boored_dev@localhost:5432/boored";
process.env.S3_ENDPOINT = process.env.S3_ENDPOINT || "http://localhost:9000";
process.env.S3_BUCKET = process.env.S3_BUCKET || "boored";
process.env.S3_ACCESS_KEY = process.env.S3_ACCESS_KEY || "minioadmin";
process.env.S3_SECRET_KEY = process.env.S3_SECRET_KEY || "minioadmin";
process.env.JWT_SECRET =
  process.env.JWT_SECRET || "d9a02c356d091165337f2e42bb68fabb39663d7e416befcc2a5f07c5a5abcb96";
process.env.GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID || "test-client-id";
process.env.NODE_ENV = "test";

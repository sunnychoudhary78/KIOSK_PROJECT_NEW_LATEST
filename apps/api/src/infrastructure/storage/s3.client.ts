import { GetObjectCommand, HeadObjectCommand, PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import type { AppConfig } from '../../config/index.js';
import { AppError } from '../../shared/errors.js';

export type PresignPutResult = {
  url: string;
  expiresAt: Date;
};

export type PresignGetResult = {
  url: string;
  expiresAt: Date;
};

export type HeadObjectResult = {
  contentLength: number;
};

export interface ObjectStorageClient {
  isConfigured(): boolean;
  presignPut(input: { key: string; contentType: string }): Promise<PresignPutResult>;
  presignGet(input: { key: string }): Promise<PresignGetResult>;
  headObject(key: string): Promise<HeadObjectResult | null>;
}

export function isObjectStorageConfigured(config: AppConfig): boolean {
  const storage = config.objectStorage;
  return Boolean(storage.endpoint && storage.bucket && storage.accessKey && storage.secretKey);
}

export function createObjectStorageClient(config: AppConfig): ObjectStorageClient {
  if (!isObjectStorageConfigured(config)) {
    return new UnconfiguredObjectStorageClient();
  }
  return new S3ObjectStorageClient(config);
}

class UnconfiguredObjectStorageClient implements ObjectStorageClient {
  isConfigured(): boolean {
    return false;
  }

  async presignPut(): Promise<PresignPutResult> {
    throw new AppError('storage_not_configured', 'Object storage is not configured', 503);
  }

  async presignGet(): Promise<PresignGetResult> {
    throw new AppError('storage_not_configured', 'Object storage is not configured', 503);
  }

  async headObject(): Promise<HeadObjectResult | null> {
    throw new AppError('storage_not_configured', 'Object storage is not configured', 503);
  }
}

class S3ObjectStorageClient implements ObjectStorageClient {
  private readonly client: S3Client;
  private readonly bucket: string;
  private readonly putTtlSeconds: number;
  private readonly getTtlSeconds: number;

  constructor(config: AppConfig) {
    this.bucket = config.objectStorage.bucket;
    this.putTtlSeconds = config.objectStorage.putTtlSeconds;
    this.getTtlSeconds = config.objectStorage.getTtlSeconds;
    this.client = new S3Client({
      region: config.objectStorage.region || 'auto',
      endpoint: config.objectStorage.endpoint,
      credentials: {
        accessKeyId: config.objectStorage.accessKey,
        secretAccessKey: config.objectStorage.secretKey,
      },
      // AWS SDK v3 default checksums break R2/MinIO presigned PUTs.
      requestChecksumCalculation: 'WHEN_REQUIRED',
      responseChecksumValidation: 'WHEN_REQUIRED',
    });
  }

  isConfigured(): boolean {
    return true;
  }

  async presignPut(input: { key: string; contentType: string }): Promise<PresignPutResult> {
    const command = new PutObjectCommand({
      Bucket: this.bucket,
      Key: input.key,
      ContentType: input.contentType,
    });
    const url = await getSignedUrl(this.client, command, { expiresIn: this.putTtlSeconds });
    return {
      url,
      expiresAt: new Date(Date.now() + this.putTtlSeconds * 1000),
    };
  }

  async presignGet(input: { key: string }): Promise<PresignGetResult> {
    const command = new GetObjectCommand({
      Bucket: this.bucket,
      Key: input.key,
    });
    const url = await getSignedUrl(this.client, command, { expiresIn: this.getTtlSeconds });
    return {
      url,
      expiresAt: new Date(Date.now() + this.getTtlSeconds * 1000),
    };
  }

  async headObject(key: string): Promise<HeadObjectResult | null> {
    try {
      const result = await this.client.send(
        new HeadObjectCommand({
          Bucket: this.bucket,
          Key: key,
        }),
      );
      return { contentLength: result.ContentLength ?? 0 };
    } catch (error) {
      const name = typeof error === 'object' && error && 'name' in error ? String(error.name) : '';
      const status =
        typeof error === 'object' && error && '$metadata' in error
          ? (error as { $metadata?: { httpStatusCode?: number } }).$metadata?.httpStatusCode
          : undefined;
      if (name === 'NotFound' || name === 'NoSuchKey' || status === 404) {
        return null;
      }
      throw error;
    }
  }
}

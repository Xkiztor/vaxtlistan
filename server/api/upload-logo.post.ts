// server/api/upload-logo.post.ts
// import { createHash } from 'crypto';

export default defineEventHandler(async (event) => {
  try {
    // Get the multipart form data
    const form = await readMultipartFormData(event);
    
    if (!form) {
      throw createError({
        statusCode: 400,
        statusMessage: 'No form data provided',
      });
    }

    // Find the file in the form data
    const fileData = form.find(item => item.name === 'file');
    const urlData = form.find(item => item.name === 'url');
    
    if (!fileData && !urlData) {
      throw createError({
        statusCode: 400,
        statusMessage: 'No file or URL provided',
      });
    }

    const cloudinaryConfig = {
      cloudName: process.env.CLOUDINARY_CLOUD_NAME,
      apiKey: process.env.CLOUDINARY_API_KEY,
      apiSecret: process.env.CLOUDINARY_API_SECRET,
    };

    if (!cloudinaryConfig.cloudName || !cloudinaryConfig.apiKey || !cloudinaryConfig.apiSecret) {
      throw createError({
        statusCode: 500,
        statusMessage: 'Cloudinary configuration missing',
      });
    }

    let uploadResult;

    if (fileData) {
      // Upload file directly to Cloudinary
      const formData = new FormData();
      const blob = new Blob([new Uint8Array(fileData.data)], { type: fileData.type || 'image/jpeg' });
      formData.append('file', blob);
      formData.append('upload_preset', 'plantskolor_logo'); // You'll need to create this preset in Cloudinary
      formData.append('folder', 'plantskolor/logos');
      
      // Generate signature for secure upload
      const timestamp = Math.round(Date.now() / 1000);
      const paramsToSign = `folder=plantskolor/logos&timestamp=${timestamp}&upload_preset=plantskolor_logo`;
      // const signature = createHash('sha1')
      //   .update(paramsToSign + cloudinaryConfig.apiSecret)
      //   .digest('hex');
      
      formData.append('timestamp', timestamp.toString());
      formData.append('api_key', cloudinaryConfig.apiKey);
      // formData.append('signature', signature);

      const response = await fetch(
        `https://api.cloudinary.com/v1_1/${cloudinaryConfig.cloudName}/image/upload`,
        {
          method: 'POST',
          body: formData,
        }
      );

      if (!response.ok) {
        const error = await response.text();
        throw createError({
          statusCode: 400,
          statusMessage: `Cloudinary upload failed: ${error}`,
        });
      }

      uploadResult = await response.json();
    } else if (urlData) {
      // Upload from URL to Cloudinary
      const uploadUrl = urlData.data.toString();
      
      // Validate URL format
      try {
        new URL(uploadUrl);
      } catch {
        throw createError({
          statusCode: 400,
          statusMessage: 'Invalid URL format',
        });
      }

      const timestamp = Math.round(Date.now() / 1000);
      const paramsToSign = `file=${uploadUrl}&folder=plantskolor/logos&timestamp=${timestamp}&upload_preset=plantskolor_logo`;
      // const signature = createHash('sha1')
      //   .update(paramsToSign + cloudinaryConfig.apiSecret)
      //   .digest('hex');

      const formData = new FormData();
      formData.append('file', uploadUrl);
      formData.append('upload_preset', 'plantskolor_logo');
      formData.append('folder', 'plantskolor/logos');
      formData.append('timestamp', timestamp.toString());
      formData.append('api_key', cloudinaryConfig.apiKey);
      // formData.append('signature', signature);

      const response = await fetch(
        `https://api.cloudinary.com/v1_1/${cloudinaryConfig.cloudName}/image/upload`,
        {
          method: 'POST',
          body: formData,
        }
      );

      if (!response.ok) {
        const error = await response.text();
        throw createError({
          statusCode: 400,
          statusMessage: `Cloudinary upload failed: ${error}`,
        });
      }

      uploadResult = await response.json();
    }

    // Return the optimized URL for logos
    return {
      url: uploadResult.secure_url.replace('/upload/', '/upload/f_auto/'),
      originalUrl: uploadResult.secure_url,
      publicId: uploadResult.public_id,
    };

  } catch (error: any) {
    console.error('Logo upload error:', error);
    
    if (error.statusCode) {
      throw error;
    }
    
    throw createError({
      statusCode: 500,
      statusMessage: 'Internal server error during logo upload',
    });
  }
});

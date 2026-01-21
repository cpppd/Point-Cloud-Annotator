const { DynamoDBClient, PutItemCommand } = require('@aws-sdk/client-dynamodb');
const { marshall } = require('@aws-sdk/util-dynamodb');

const client = new DynamoDBClient({});
const TABLE_NAME = process.env.TABLE_NAME;

exports.handler = async (event) => {
  console.log('POST annotation request:', JSON.stringify(event));

  const headers = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'
  };

  try {
    // Parse the request body
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;

    // Validate required fields
    if (!body.uuid) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({
          success: false,
          error: 'Missing required field: uuid'
        })
      };
    }

    // Build the annotation item
    const now = new Date().toISOString();
    const item = {
      uuid: body.uuid,
      title: body.title || 'No Title',
      description: body.description || '',
      // Position coordinates
      positionX: body.positionX ?? body.position?.x ?? 0,
      positionY: body.positionY ?? body.position?.y ?? 0,
      positionZ: body.positionZ ?? body.position?.z ?? 0,
      // Camera position coordinates
      cameraPositionX: body.cameraPositionX ?? body.cameraPosition?.x ?? null,
      cameraPositionY: body.cameraPositionY ?? body.cameraPosition?.y ?? null,
      cameraPositionZ: body.cameraPositionZ ?? body.cameraPosition?.z ?? null,
      // Camera target coordinates
      cameraTargetX: body.cameraTargetX ?? body.cameraTarget?.x ?? null,
      cameraTargetY: body.cameraTargetY ?? body.cameraTarget?.y ?? null,
      cameraTargetZ: body.cameraTargetZ ?? body.cameraTarget?.z ?? null,
      // Optional radius
      radius: body.radius ?? null,
      // Timestamps
      updatedAt: now
    };

    // Add createdAt only if this is a new record (we'll use conditional expression)
    if (body.createdAt) {
      item.createdAt = body.createdAt;
    } else {
      item.createdAt = now;
    }

    // Remove null values for DynamoDB
    const cleanItem = Object.fromEntries(
      Object.entries(item).filter(([_, v]) => v !== null && v !== undefined)
    );

    console.log('Saving annotation:', JSON.stringify(cleanItem));

    const command = new PutItemCommand({
      TableName: TABLE_NAME,
      Item: marshall(cleanItem)
    });

    await client.send(command);

    console.log('Annotation saved successfully');

    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({
        success: true,
        message: 'Annotation saved successfully',
        annotation: cleanItem
      })
    };
  } catch (error) {
    console.error('Error saving annotation:', error);

    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({
        success: false,
        error: 'Failed to save annotation',
        message: error.message
      })
    };
  }
};

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand, DeleteCommand, ScanCommand } from "@aws-sdk/lib-dynamodb";
import { S3Client, PutObjectCommand, DeleteObjectCommand, ListObjectsV2Command } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);
const s3Client = new S3Client({});

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "https://main.d3dhvqli97edsu.amplifyapp.com",
  "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
  "Access-Control-Allow-Methods": "GET,OPTIONS,POST,PUT,DELETE",
  "Access-Control-Allow-Credentials": "true"
};

export const handler = async (event) => {
  console.log("Event:", JSON.stringify(event));
  
  if (event.httpMethod === "OPTIONS") {
    return { statusCode: 200, headers: CORS_HEADERS, body: "" };
  }

  const { body } = event;
  const COURSES_TABLE = process.env.COURSES_TABLE;
  const EVALUATIONS_TABLE = process.env.EVALUATIONS_TABLE;
  const S3_BUCKET = process.env.S3_BUCKET;

  try {
    const data = JSON.parse(body);
    const { action, courseId, course, evaluations } = data;

    // 1. CREATE OR UPDATE COURSE
    if (action === "createCourse") {
      const id = courseId || `crs_${Date.now()}`;
      
      await docClient.send(new PutCommand({
        TableName: COURSES_TABLE,
        Item: {
          courseId: id,
          title: course.title,
          description: course.description,
          modules: course.modules,
          updatedAt: new Date().toISOString()
        }
      }));

      if (evaluations && evaluations.length > 0) {
        for (const evalItem of evaluations) {
          await docClient.send(new PutCommand({
            TableName: EVALUATIONS_TABLE,
            Item: {
              courseId: id,
              questionId: "FINAL_EXAM",
              title: evalItem.title,
              questions: evalItem.questions,
              passingScore: 80,
              updatedAt: new Date().toISOString()
            }
          }));
        }
      }

      const presignedUrls = await Promise.all(course.modules.map(async (mod, idx) => {
        const key = `videos/${id}/module_${idx}_${Date.now()}.mp4`;
        const command = new PutObjectCommand({
          Bucket: S3_BUCKET,
          Key: key,
          ContentType: "video/mp4"
        });
        const url = await getSignedUrl(s3Client, command, { expiresIn: 3600 });
        return { moduleIndex: idx, url, key };
      }));

      return {
        statusCode: 201,
        headers: CORS_HEADERS,
        body: JSON.stringify({ message: "Course saved successfully", courseId: id, presignedUrls })
      };
    }

    // 2. DELETE COURSE
    if (action === "deleteCourse") {
      if (!courseId) return { statusCode: 400, headers: CORS_HEADERS, body: JSON.stringify({ message: "Missing courseId" }) };

      await docClient.send(new DeleteCommand({ TableName: COURSES_TABLE, Key: { courseId } }));

      const evals = await docClient.send(new ScanCommand({
        TableName: EVALUATIONS_TABLE,
        FilterExpression: "courseId = :cid",
        ExpressionAttributeValues: { ":cid": courseId }
      }));
      for (const item of (evals.Items || [])) {
        await docClient.send(new DeleteCommand({ TableName: EVALUATIONS_TABLE, Key: { courseId: item.courseId, questionId: item.questionId } }));
      }

      const listCommand = new ListObjectsV2Command({ Bucket: S3_BUCKET, Prefix: `videos/${courseId}/` });
      const listedObjects = await s3Client.send(listCommand);
      if (listedObjects.Contents && listedObjects.Contents.length > 0) {
        for (const obj of listedObjects.Contents) {
          await s3Client.send(new DeleteObjectCommand({ Bucket: S3_BUCKET, Key: obj.Key }));
        }
      }

      return {
        statusCode: 200,
        headers: CORS_HEADERS,
        body: JSON.stringify({ message: "Course and associated data deleted" })
      };
    }

    // 3. SAVE EVALUATION
    if (action === "saveEvaluation") {
      const { courseId, title, questions } = data;
      if (!courseId) return { statusCode: 400, headers: CORS_HEADERS, body: JSON.stringify({ message: "Missing courseId" }) };

      await docClient.send(new PutCommand({
        TableName: EVALUATIONS_TABLE,
        Item: {
          courseId,
          questionId: "FINAL_EXAM",
          title: title || "Examen Final",
          questions: questions || [],
          passingScore: 80,
          updatedAt: new Date().toISOString()
        }
      }));

      return {
        statusCode: 200,
        headers: CORS_HEADERS,
        body: JSON.stringify({ message: "Evaluation saved successfully" })
      };
    }

    return {
      statusCode: 400,
      headers: CORS_HEADERS,
      body: JSON.stringify({ message: "Invalid action" })
    };
  } catch (error) {
    console.error(error);
    return {
      statusCode: 500,
      headers: CORS_HEADERS,
      body: JSON.stringify({ message: "Internal Server Error", error: error.message })
    };
  }
};

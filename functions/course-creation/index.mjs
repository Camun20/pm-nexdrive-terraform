import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand } from "@aws-sdk/lib-dynamodb";
import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);
const s3Client = new S3Client({});

export const handler = async (event) => {
  console.log("Event:", JSON.stringify(event));
  const { body } = event;
  const COURSES_TABLE = process.env.COURSES_TABLE;
  const EVALUATIONS_TABLE = process.env.EVALUATIONS_TABLE;
  const S3_BUCKET = process.env.S3_BUCKET;

  try {
    const data = JSON.parse(body);
    const { action, course, evaluations } = data;

    if (action === "createCourse") {
      const courseId = `crs_${Date.now()}`;
      
      // 1. Save Course Metadata
      await docClient.send(new PutCommand({
        TableName: COURSES_TABLE,
        Item: {
          courseId,
          title: course.title,
          description: course.description,
          modules: course.modules, // Array of modules
          createdAt: new Date().toISOString()
        }
      }));

      // 2. Save Evaluations if any
      if (evaluations && evaluations.length > 0) {
        for (const evalItem of evaluations) {
          await docClient.send(new PutCommand({
            TableName: EVALUATIONS_TABLE,
            Item: {
              courseId: courseId,
              questionId: "FINAL_EXAM", // We store the whole exam as one record for now
              title: evalItem.title,
              questions: evalItem.questions, // Array of multiple choice questions
              passingScore: 80,
              updatedAt: new Date().toISOString()
            }
          }));
        }
      }

      // 3. Generate Pre-signed URLs for each module video if needed
      // Or just return one for the main upload if the frontend asks for it
      const presignedUrls = await Promise.all(course.modules.map(async (mod, idx) => {
        const key = `videos/${courseId}/module_${idx}_${Date.now()}.mp4`;
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
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
        body: JSON.stringify({
          message: "Course created successfully",
          courseId,
          presignedUrls
        })
      };
    }

    return {
      statusCode: 400,
      body: JSON.stringify({ message: "Invalid action" })
    };
  } catch (error) {
    console.error(error);
    return {
      statusCode: 500,
      body: JSON.stringify({ message: "Internal Server Error", error: error.message })
    };
  }
};

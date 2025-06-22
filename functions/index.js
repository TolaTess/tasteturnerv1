/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { GoogleGenerativeAI } = require("@google/generative-ai");

admin.initializeApp();

// Initialize the Gemini client with the API key from function configuration
const genAI = new GoogleGenerativeAI(functions.config().gemini.key);
const firestore = admin.firestore();

/**
 * A scheduled Cloud Function that generates new ingredients for the weekly battle.
 * - Runs every Monday at 1:00 AM.
 * - Generates two ingredients using the Gemini API.
 * - Updates the 'general' battle document in Firestore with the new battle data.
 */
exports.generateBattleIngredients = functions.pubsub
  .schedule("every monday 01:00")
  .timeZone("America/New_York") // IMPORTANT: Set to your preferred timezone
  .onRun(async (context) => {
    console.log("Running weekly ingredient generation job.");

    try {
      // 1. Generate ingredients with Gemini. Retry logic added for robustness.
      let ingredientsData = [];
      let attempts = 0;
      const maxAttempts = 3;

      while (ingredientsData.length < 2 && attempts < maxAttempts) {
        attempts++;
        console.log(`Attempt ${attempts} to generate and find ingredients.`);
        
        const model = genAI.getGenerativeModel({ model: "gemini-pro" });
        const prompt =
          "Give me two common cooking ingredients that can be paired together for a cooking challenge. They should be relatively easy to find. Return them as a simple comma-separated list, for example: 'Chicken Breast, Broccoli'. Do not add any other text, formatting, or quotation marks.";

        const result = await model.generateContent(prompt);
        const response = await result.response;
        const text = response.text();
        const ingredientNames = text.split(",").map((item) => item.trim());

        if (ingredientNames.length < 2) {
          console.log(
            `Gemini did not return two ingredients. Raw response: "${text}"`
          );
          continue; // Try again
        }

        // 2. Look up ingredients in Firestore
        const ingredientsRef = firestore.collection("ingredients");
        const foundIngredients = [];

        for (const name of ingredientNames) {
          // Use .toLowerCase() for case-insensitive matching
          const snapshot = await ingredientsRef
            .where("name", "==", name.toLowerCase())
            .limit(1)
            .get();
          
          if (!snapshot.empty) {
            const doc = snapshot.docs[0];
            foundIngredients.push({
              id: doc.id,
              name: doc.data().name, // Use the canonical name from DB
              image: doc.data().image,
            });
          } else {
            console.log(`Ingredient "${name}" not found in Firestore.`);
          }
        }
        
        if(foundIngredients.length === 2) {
            ingredientsData = foundIngredients;
        }
      }

      if (ingredientsData.length < 2) {
          console.error("Failed to find two valid ingredients after several attempts. Aborting.");
          return null;
      }

      console.log(`Found ingredients in Firestore:`, ingredientsData);

      // 3. Prepare data for Firestore update
      const battleRef = firestore.collection("battles").doc("general");

      // Calculate date keys
      const today = new Date();
      const battleDateKey = `${today.getFullYear()}-${String(
        today.getMonth() + 1
      ).padStart(2, "0")}-${String(today.getDate()).padStart(2, "0")}`;
      
      const deadline = new Date(today);
      deadline.setDate(today.getDate() + 6); // Deadline is Sunday

      // Find the most recent battle date to set as 'prevBattle'
      const battleDoc = await battleRef.get();
      let prevBattleKey = null;
      if (battleDoc.exists && battleDoc.data().dates) {
        const dateKeys = Object.keys(battleDoc.data().dates);
        dateKeys.sort(); // Sort dates chronologically
        prevBattleKey = dateKeys.pop(); // Get the most recent one
      }
      
      // 4. Construct the update payload to create the new battle week
      const newBattlePayload = {
        [`dates.${battleDateKey}`]: {
          ingredients: ingredientsData,
          participants: {},
          voted: [],
          status: "active",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          battleDeadline: admin.firestore.Timestamp.fromDate(deadline),
        },
      };
      await battleRef.set(newBattlePayload, { merge: true });

      // 5. Update the main 'general/data' document with the new week's state
      const generalDataRef = firestore.collection("general").doc("data");
      await generalDataRef.set({
          currentBattle: battleDateKey,
          prevBattle: prevBattleKey,
          battleDeadline: admin.firestore.Timestamp.fromDate(deadline)
      }, { merge: true });

      console.log(`Successfully created new battle for date: ${battleDateKey}`);
      return null;
    } catch (error) {
      console.error("Error generating battle ingredients:", error);
      return null;
    }
  });

/**
 * A scheduled Cloud Function that processes the end of a battle.
 * - Runs every Monday at 12:30 AM.
 * - Finds the most recently concluded battle.
 * - Calculates winners based on votes.
 * - Awards points to winners.
 * - Saves a record of the winners.
 */
exports.processBattleEnd = functions.pubsub
  .schedule("every monday 00:30")
  .timeZone("America/New_York") // IMPORTANT: Set to your preferred timezone
  .onRun(async (context) => {
    console.log("Running weekly battle processing job.");

    try {
      const generalDataRef = firestore.collection("general").doc("data");
      const generalDataDoc = await generalDataRef.get();
      // Use currentBattle, as this is the one that is ending.
      const battleKeyToProcess = generalDataDoc.data()?.currentBattle;

      if (!battleKeyToProcess) {
        console.log("No current battle key found. Nothing to process.");
        return null;
      }

      // 1. Get the battle data that just ended
      const battleRef = firestore.collection("battles").doc("general");
      const battleDoc = await battleRef.get();

      if (
        !battleDoc.exists ||
        !battleDoc.data().dates ||
        !battleDoc.data().dates[battleKeyToProcess]
      ) {
        console.error(`Data for previous battle ${battleKeyToProcess} not found.`);
        return null;
      }

      const battleData = battleDoc.data().dates[battleKeyToProcess];
      const participants = battleData.participants || {};

      // Mark battle as ended regardless of participant count
      await battleRef.update({
        [`dates.${battleKeyToProcess}.status`]: "ended",
      });

      if (Object.keys(participants).length < 2) {
        console.log("Not enough participants to determine a winner. Battle marked as ended.");
        return null;
      }

      // 2. Calculate winners
      const sortedParticipants = Object.entries(participants)
        .map(([userId, data]) => ({
          userId,
          votes: (data.votes || []).length,
        }))
        .sort((a, b) => b.votes - a.votes);
      
      const winners = sortedParticipants.slice(0, 2); // Top 2 winners

      // 3. Award points and save winner records
      const winnersToSave = {};
      const pointsToAward = [30, 20]; // 1st, 2nd

      for (let i = 0; i < winners.length; i++) {
        const winner = winners[i];
        const points = pointsToAward[i];
        
        // Update points
        const userPointsRef = firestore.collection("points").doc(winner.userId);
        await firestore.runTransaction(async (transaction) => {
            const userPointsDoc = await transaction.get(userPointsRef);
            const currentPoints = userPointsDoc.exists ? userPointsDoc.data().points : 0;
            transaction.set(userPointsRef, { points: currentPoints + points }, { merge: true });
        });

        // Add to winners list for historical record
        winnersToSave[winner.userId] = {
            position: i + 1,
            votes: winner.votes,
            pointsAwarded: points,
        };
      }

      const weekId = `week_${battleKeyToProcess}`;
      await firestore.collection("winners").doc(weekId).set({
          date: battleKeyToProcess,
          winners: winnersToSave,
      });

      // 4. Update the announcement date to today
      const today = new Date();
      const announceDateString = `${today.getFullYear()}-${String(
        today.getMonth() + 1
      ).padStart(2, "0")}-${String(today.getDate()).padStart(2, "0")}`;

      await generalDataRef.update({
        isAnnounceDate: announceDateString,
      });

      console.log(`Successfully processed battle for ${battleKeyToProcess}. Winners:`, winners);
      return null;
    } catch (error) {
      console.error("Error processing battle end:", error);
      return null;
    }
  });

/**
 * A Firestore-triggered Cloud Function that calculates and aggregates daily nutritional data.
 * - Triggers on any write to a user's daily meal document.
 * - Calculates total calories, protein, carbs, and fat for the day.
 * - Saves the aggregated data to a 'daily_summary' collection for efficient client-side reads.
 */
exports.calculateDailyNutrition = functions.firestore
  .document("userMeals/{userId}/meals/{date}")
  .onWrite(async (change, context) => {
    const { userId, date } = context.params;
    const summaryRef = firestore
      .collection("users")
      .doc(userId)
      .collection("daily_summary")
      .doc(date);

    // If the document was deleted, we should delete the summary as well.
    if (!change.after.exists) {
      console.log(`Meals deleted for ${userId} on ${date}. Deleting summary.`);
      return summaryRef.delete();
    }

    const data = change.after.data();
    const meals = data.meals || {};

    // 1. Calculate the totals
    let totalCalories = 0;
    let totalProtein = 0;
    let totalCarbs = 0;
    let totalFat = 0;
    const mealTotals = {};

    // The 'meals' field is a map of meal types (Breakfast, Lunch, etc.) to lists of food items
    for (const mealType in meals) {
      if (Array.isArray(meals[mealType])) {
        let mealTypeCalories = 0;
        meals[mealType].forEach((item) => {
          const itemCalories = item.calories || 0;
          totalCalories += itemCalories;
          mealTypeCalories += itemCalories;
          totalProtein += item.protein || 0;
          totalCarbs += item.carbs || 0;
          totalFat += item.fat || 0;
        });
        mealTotals[mealType] = mealTypeCalories;
      }
    }

    const summaryData = {
      calories: totalCalories,
      protein: totalProtein,
      carbs: totalCarbs,
      fat: totalFat,
      mealTotals: mealTotals, // Add the per-meal breakdown
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    };

    console.log(
      `Updating summary for ${userId} on ${date}:`,
      summaryData
    );

    // 2. Write the summary data
    return summaryRef.set(summaryData, { merge: true });
  });

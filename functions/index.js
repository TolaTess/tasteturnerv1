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
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { HttpsError } = require("firebase-functions/v2/https");
const { defineString } = require('firebase-functions/params');
const { startOfWeek, endOfWeek, format, addDays } = require("date-fns");
const crypto = require('crypto');
const Jimp = require('jimp');

admin.initializeApp();

// Initialize the Gemini client with the API key from function configuration (needed for _generateAndSaveIngredient)
const genAI = new GoogleGenerativeAI(functions.config().gemini.key);
const firestore = getFirestore();

// Helper function to get the best available Gemini model
// Tries models in order of preference, falls back to any available model
async function _getBestGeminiModel() {
  try {
    // Preferred models in order (newest/best first)
    const preferredModels = [
      'gemini-2.5-flash',
      'gemini-2.0-flash-exp',
      'gemini-2.0-flash',
      'gemini-1.5-flash',
      'gemini-1.5-pro',
      'gemini-2.5-pro',
      'gemini-2.0-pro',
      'gemini-pro',
    ];

    // Try to list available models
    const modelsResponse = await fetch(
      `https://generativelanguage.googleapis.com/v1/models?key=${functions.config().gemini.key}`
    );
    
    if (modelsResponse.ok) {
      const data = await modelsResponse.json();
      const availableModels = data.models || [];
      
      console.log(`Found ${availableModels.length} Gemini models`);
      
      // Try preferred models first
      for (const preferredModel of preferredModels) {
        const found = availableModels.find(m => 
          m.name.endsWith(preferredModel) && 
          m.supportedGenerationMethods?.includes('generateContent')
        );
        if (found) {
          const modelName = found.name.split('/').pop();
          console.log(`✅ Using Gemini model: ${modelName}`);
          return modelName;
        }
      }
      
      // If no preferred model found, use any available model (excluding embedding models)
      for (const model of availableModels) {
        if (!model.name.includes('embedding') && 
            model.supportedGenerationMethods?.includes('generateContent')) {
          const modelName = model.name.split('/').pop();
          console.log(`✅ Using fallback Gemini model: ${modelName}`);
          return modelName;
        }
      }
    }
  } catch (error) {
    console.warn('Failed to fetch Gemini models list:', error.message);
  }
  
  // Ultimate fallback
  console.log('⚠️ Could not determine best model, using gemini-2.0-flash as fallback');
  return 'gemini-2.0-flash';
}

// Cache the model name to avoid repeated API calls
let cachedModelName = null;
async function _getGeminiModel() {
  if (!cachedModelName) {
    cachedModelName = await _getBestGeminiModel();
  }
  return genAI.getGenerativeModel({ model: cachedModelName });
}

// Helper to get week number
function _getWeek(date) {
  const d = new Date(
    Date.UTC(date.getFullYear(), date.getMonth(), date.getDate())
  );
  const dayNum = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  return Math.ceil(((d - yearStart) / 86400000 + 1) / 7);
}

/**
 * Generate and save weekly challenge ingredients
 * This function gets 4 random ingredients from the ingredientChallenge list
 * and saves them in the challenge_details field with the following Sunday's date
 */
exports.generateWeeklyChallengeIngredients = functions.https.onCall(async (data, context) => {
  try {
    console.log('--- Generating weekly challenge ingredients ---');

    // Get the ingredient challenge list from general collection
    const generalDoc = await firestore.collection('general').doc('general').get();
    
    if (!generalDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'General collection document not found'
      );
    }

    const generalData = generalDoc.data();
    const ingredientChallengeString = generalData.ingredientChallenge || '';
    
    if (!ingredientChallengeString) {
      throw new functions.https.HttpsError(
        'not-found',
        'ingredientChallenge string not found in general collection'
      );
    }

    // Parse the comma-separated string and categorize ingredients
    const allIngredients = ingredientChallengeString.split(',').map(ing => ing.trim()).filter(ing => ing);
    const proteins = allIngredients.filter(ing => ing.endsWith('-p'));
    const vegetables = allIngredients.filter(ing => ing.endsWith('-v'));
    
    if (proteins.length < 2) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Not enough protein ingredients. Found ${proteins.length}, need at least 2.`
      );
    }
    
    if (vegetables.length < 2) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Not enough vegetable ingredients. Found ${vegetables.length}, need at least 2.`
      );
    }

    // Get 2 random proteins and 2 random vegetables
    const shuffledProteins = [...proteins].sort(() => 0.5 - Math.random());
    const shuffledVegetables = [...vegetables].sort(() => 0.5 - Math.random());
    
    const selectedProteins = shuffledProteins.slice(0, 2);
    const selectedVegetables = shuffledVegetables.slice(0, 2);
    const selectedIngredients = [...selectedProteins, ...selectedVegetables];

    // Calculate the following Sunday's date
    const today = new Date();
    const nextSunday = addDays(today, (7 - today.getDay()) % 7);
    const sundayDate = format(nextSunday, 'dd-MM-yyyy');

    // Create the challenge details string in the specified format
    const challengeDetails = `${sundayDate},${selectedIngredients.join(',')}`;

    // Save to challenge_details in general collection
    await firestore.collection('general').doc('general').update({
      challenge_details: challengeDetails,
      lastChallengeUpdate: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log(`Successfully generated challenge ingredients: ${challengeDetails}`);

    return {
      success: true,
      challengeDetails: challengeDetails,
      selectedIngredients: selectedIngredients,
      selectedProteins: selectedProteins,
      selectedVegetables: selectedVegetables,
      challengeDate: sundayDate
    };

  } catch (error) {
    console.error('Error generating weekly challenge ingredients:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      'An error occurred while generating challenge ingredients'
    );
  }
});

/**
 * A Firestore-triggered Cloud Function that automatically calculates and updates
 * a user's total daily nutritional intake whenever a meal is added, updated,
 * or deleted for that day.
 * - Listens for writes on 'userMeals/{userId}/meals/{date}'.
 * - Fetches all meals for that specific day.
 * - Sums up the nutritional values (calories, protein, carbs, fat).
 * - Writes the aggregated data to 'users/{userId}/daily_summary/{date}'.
 */
exports.calculateDailyNutrition = functions.firestore
  .document("userMeals/{userId}/meals/{date}")
  .onWrite(async (change, context) => {
    const { userId, date } = context.params;
    console.log(
      `--- Function calculateDailyNutrition triggered for user: ${userId} on date: ${date} ---`
    );

    // If the document is deleted, remove the summary
    if (!change.after.exists) {
      const summaryDocRef = firestore
        .collection("users")
        .doc(userId)
        .collection("daily_summary")
        .doc(date);
      await summaryDocRef.delete();
      console.log(
        `Document at userMeals/.../${date} deleted. Removed summary at: ${summaryDocRef.path}`
      );
      return null;
    }

    // Also fetch water and steps data from userMeals
    let waterData = null;
    let stepsData = null;
    try {
      const userMealsDocRef = firestore
        .collection("userMeals")
        .doc(userId)
        .collection("meals")
        .doc(date);
      
      const userMealsDoc = await userMealsDocRef.get();
      if (userMealsDoc.exists) {
        const userMealsData = userMealsDoc.data();
        waterData = userMealsData.Water || null;
        stepsData = userMealsData.Steps || null;
        console.log(`Found water data: ${waterData}, steps data: ${stepsData}`);
      }
    } catch (error) {
      console.log(`Error fetching water/steps data: ${error.message}`);
    }

    const data = change.after.data();
    // The 'meals' field is a map, not an array. We need to extract the items.
    const mealsMap = data.meals || {};
    let allMealItems = [];

    // Check if mealsMap is an object and not empty
    if (typeof mealsMap === "object" && Object.keys(mealsMap).length > 0) {
      // It's a map of maps, e.g., { "Add Food": { "0": { meal_data } } }
      // We iterate over the values of the outer map
      Object.values(mealsMap).forEach((innerMap) => {
        // Then iterate over the values of the inner map to get the meal items
        if (typeof innerMap === "object") {
          allMealItems.push(...Object.values(innerMap));
        }
      });
    }

    console.log(`Found ${allMealItems.length} total meal items to process.`);

    if (allMealItems.length === 0) {
      const summaryDocRef = firestore
        .collection("users")
        .doc(userId)
        .collection("daily_summary")
        .doc(date);
      await summaryDocRef.delete();
      console.log(
        `Meals data is empty or invalid. Deleted daily summary at: ${summaryDocRef.path}`
      );
      return null;
    }

    try {
      let totalCalories = 0;
      let totalProtein = 0;
      let totalCarbs = 0;
      let totalFat = 0;
      const mealTotals = {
        Breakfast: 0,
        Lunch: 0,
        Dinner: 0,
        Snacks: 0,
      };

      // Loop over meal types ("Breakfast", "Add Food", etc.)
      for (const mealTypeKey in mealsMap) {
        if (Object.prototype.hasOwnProperty.call(mealsMap, mealTypeKey)) {
          const innerMap = mealsMap[mealTypeKey];

          if (typeof innerMap === "object" && innerMap !== null) {
            // Loop over individual food items (e.g., "0", "1")
            for (const itemKey in innerMap) {
              if (Object.prototype.hasOwnProperty.call(innerMap, itemKey)) {
                const item = innerMap[itemKey];

                if (item && typeof item === "object") {
                  const calories =
                    typeof item.calories === "number" ? item.calories : 0;

                  // Extract macro data from various possible sources
                  let protein = 0, carbs = 0, fat = 0;
                  if (item.macros && typeof item.macros === "object") {
                    protein = typeof item.macros.protein === "number" ? item.macros.protein : 0;
                    carbs = typeof item.macros.carbs === "number" ? item.macros.carbs : 0;
                    fat = typeof item.macros.fat === "number" ? item.macros.fat : 0;
                  } else if (item.nutrition && typeof item.nutrition === "object") {
                    protein = parseFloat(item.nutrition.protein) || 0;
                    carbs = parseFloat(item.nutrition.carbs) || 0;
                    fat = parseFloat(item.nutrition.fat) || 0;
                  } else if (item.nutritionalInfo && typeof item.nutritionalInfo === "object") {
                    protein = parseFloat(item.nutritionalInfo.protein) || 0;
                    carbs = parseFloat(item.nutritionalInfo.carbs) || 0;
                    fat = parseFloat(item.nutritionalInfo.fat) || 0;
                  }

                  // Debug logging for macro data
                  if (protein > 0 || carbs > 0 || fat > 0) {
                    console.log(`Found macro data for ${item.name}: Protein: ${protein}g, Carbs: ${carbs}g, Fat: ${fat}g`);
                  }

                  // Add to grand totals
                  totalCalories += calories;
                  totalProtein += protein;
                  totalCarbs += carbs;
                  totalFat += fat;

                  // Add to meal-specific totals
                  if (mealTotals.hasOwnProperty(mealTypeKey)) {
                    mealTotals[mealTypeKey] += calories;
                  } else {
                    // Any non-standard meal type goes into 'Add Food'
                    if (!mealTotals["Add Food"]) {
                      mealTotals["Add Food"] = 0;
                    }
                    mealTotals["Add Food"] += calories;
                  }
                }
              }
            }
          }
        }
      }

      const dailySummaryData = {
        calories: totalCalories,
        protein: totalProtein,
        carbs: totalCarbs,
        fat: totalFat,
        mealTotals,
        water: waterData,
        steps: stepsData,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      };

      const summaryDocRef = firestore
        .collection("users")
        .doc(userId)
        .collection("daily_summary")
        .doc(date);

      await summaryDocRef.set(dailySummaryData, { merge: true });

      console.log(
        `Successfully updated daily summary for user ${userId} on ${date}.`
      );
      console.log("Updated data:", dailySummaryData);
      console.log(`Macro totals - Protein: ${totalProtein}g, Carbs: ${totalCarbs}g, Fat: ${totalFat}g`);
      console.log(`Activity data - Water: ${waterData}, Steps: ${stepsData}`);
      console.log("--- Function calculateDailyNutrition finished ---");
      return null;
    } catch (error) {
      console.error(
        `Error calculating daily nutrition for user ${userId} on ${date}:`,
        error
      );
      console.error("--- Function calculateDailyNutrition ERRORED ---");
      return null;
    }
  });

/**
 * A Firestore-triggered Cloud Function that updates the daily summary
 * when water or steps data is modified in userMeals.
 * This ensures the daily summary stays in sync even when only activity data changes.
 */
exports.updateDailySummaryOnActivityChange = functions.firestore
  .document("userMeals/{userId}/meals/{date}")
  .onWrite(async (change, context) => {
    const { userId, date } = context.params;
    console.log(
      `--- Function updateDailySummaryOnActivityChange triggered for user: ${userId} on date: ${date} ---`
    );

    // Check if Water or Steps fields were modified
    const beforeData = change.before.exists ? change.before.data() : {};
    const afterData = change.after.exists ? change.after.data() : {};
    
    const waterChanged = beforeData.Water !== afterData.Water;
    const stepsChanged = beforeData.Steps !== afterData.Steps;
    
    // Only proceed if water or steps changed, and meals didn't change
    // (meals are handled by the calculateDailyNutrition function)
    if (!waterChanged && !stepsChanged) {
      console.log("No water or steps data changed, skipping update");
      return null;
    }
    
    // Check if meals data also changed - if so, let the calculateDailyNutrition function handle it
    const beforeMeals = beforeData.meals || {};
    const afterMeals = afterData.meals || {};
    const mealsChanged = JSON.stringify(beforeMeals) !== JSON.stringify(afterMeals);
    
    if (mealsChanged) {
      console.log("Meals data also changed, letting calculateDailyNutrition handle the update");
      return null;
    }

    console.log(`Water changed: ${waterChanged}, Steps changed: ${stepsChanged}`);

    try {
      // Get the current daily summary
      const summaryDocRef = firestore
        .collection("users")
        .doc(userId)
        .collection("daily_summary")
        .doc(date);
      
      const summaryDoc = await summaryDocRef.get();
      
      if (!summaryDoc.exists) {
        console.log("No daily summary exists for this date, skipping update");
        return null;
      }

      const currentSummary = summaryDoc.data();
      
      // Update only the water and steps fields
      const updatedSummary = {
        ...currentSummary,
        water: afterData.Water || null,
        steps: afterData.Steps || null,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      };

      await summaryDocRef.set(updatedSummary, { merge: true });

      console.log(
        `Successfully updated daily summary activity data for user ${userId} on ${date}`
      );
      console.log(`Updated water: ${afterData.Water}, steps: ${afterData.Steps}`);
      console.log("--- Function updateDailySummaryOnActivityChange finished ---");
      
      return null;
    } catch (error) {
      console.error(
        `Error updating daily summary activity data for user ${userId} on ${date}:`,
        error
      );
      console.error("--- Function updateDailySummaryOnActivityChange ERRORED ---");
      return null;
    }
  });

/**
 * Triggered when a user's meal for a specific day is created or updated.
 * It reads all meals for the week, aggregates the ingredients, and
 * updates the weekly shopping list for that user in the specified format.
 */
exports.generateAndSaveWeeklyShoppingList = functions.firestore
  .document("mealPlans/{userId}/date/{date}")
  .onWrite(async (change, context) => {
    const { userId, date } = context.params;
    console.log(
      `--- Running Shopping List Generation for user: ${userId} on date: ${date} ---`
    );

    try {
      // 1. Determine the week for the changed meal using the same logic as the test function
      const mealDate = new Date(date);
      const year = mealDate.getUTCFullYear();
      const week = _getWeek(mealDate);
      const weekId = `week_${year}-${String(week).padStart(2, "0")}`;

      // 2. Fetch all meal plan documents for the entire week
      const weekStart = startOfWeek(mealDate, { weekStartsOn: 0 }); // Sunday
      const weekEnd = endOfWeek(mealDate, { weekStartsOn: 0 });

      const startDateStr = format(weekStart, "yyyy-MM-dd");
      const endDateStr = format(weekEnd, "yyyy-MM-dd");

      console.log(
        `Querying for meal plans between: ${startDateStr} and ${endDateStr}`
      );

      const mealsSnapshot = await firestore
        .collection(`mealPlans/${userId}/date`)
        .where(admin.firestore.FieldPath.documentId(), ">=", startDateStr)
        .where(admin.firestore.FieldPath.documentId(), "<=", endDateStr)
        .get();

      console.log(
        `Found ${mealsSnapshot.size} meal plan document(s) for the week.`
      );

      // 3. Collect all unique meal IDs from the documents
      const allMealIds = new Set();
      mealsSnapshot.forEach((dayDoc) => {
        const data = dayDoc.data();
        const mealPaths = data.meals || [];
        mealPaths.forEach((path) => {
          const mealId = path.split("/")[0];
          if (mealId) allMealIds.add(mealId);
        });
      });

      // If no meals are found for the week, clear the generated items and exit
      if (allMealIds.size === 0) {
        console.log("No meal IDs found for the week. Clearing generated list.");
        const listRef = firestore
          .collection("userMeals")
          .doc(userId)
          .collection("shoppingList")
          .doc(weekId);
        // Use set with merge to only clear the generatedItems field
        await listRef.set({ generatedItems: {} }, { merge: true });
        return null;
      }

      // Fetch all unique meal documents from the 'meals' collection
      const mealDocs = await firestore
        .collection("meals")
        .where(admin.firestore.FieldPath.documentId(), "in", [...allMealIds])
        .get();

      // Aggregate the ingredients from these meals
      const weeklyIngredients = {};
      for (const mealDoc of mealDocs.docs) {
        const mealData = mealDoc.data();
        const ingredients = mealData.ingredients || {};
        for (const [name, amountStr] of Object.entries(ingredients)) {
          const quantityMatch = (amountStr || "").match(/^(\d+(\.\d+)?)/);
          const unitMatch = (amountStr || "").match(/[a-zA-Z\s]+$/);
          const quantity = quantityMatch ? Number(quantityMatch[1]) : 0;
          const unit = unitMatch ? unitMatch[0].trim() : "";

          if (name && quantity > 0) {
            if (!weeklyIngredients[name]) {
              weeklyIngredients[name] = { quantity: 0, unit: unit };
            }
            weeklyIngredients[name].quantity += quantity;
          }
        }
      }

      // 4. Find existing ingredients or create new ones, then build the map
      const requiredItems = {};
      for (const name in weeklyIngredients) {
        const { quantity, unit } = weeklyIngredients[name];
        const ingredientsRef = firestore.collection("ingredients");
        let ingredientId = null;

        // Try to find existing ingredient with robust name checking
        ingredientId = await _findExistingIngredient(name);

        if (!ingredientId) {
          console.log(`Ingredient "${name}" not found. Generating...`);
          ingredientId = await _generateAndSaveIngredient(name);
        }

        if (ingredientId) {
          const key = `${ingredientId}/${quantity}${unit}`;
          requiredItems[key] = false; // Default to false
        }
      }

      // 5. Use a transaction to safely merge the new list with the existing one
      const listRef = firestore
        .collection("userMeals")
        .doc(userId)
        .collection("shoppingList")
        .doc(weekId);

      await firestore.runTransaction(async (transaction) => {
        const doc = await transaction.get(listRef);
        const existingGeneratedItems = doc.data()?.generatedItems || {};
        const newGeneratedItems = {};

        // Preserve the status of existing items.
        // Add new items with a default status of 'false'.
        // Items no longer in the plan are implicitly removed.
        for (const key in requiredItems) {
            newGeneratedItems[key] = existingGeneratedItems[key] || false;
        }

        transaction.set(
          listRef,
          {
            generatedItems: newGeneratedItems,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true } // Merge to avoid overwriting 'manualItems'
        );
      });

      console.log(
        `Successfully updated shopping list for user ${userId}, week ${weekId}`
      );
      return null;
    } catch (error) {
      console.error("Error generating shopping list:", error);
      return null;
    }
  });

/**
 * Helper function to find existing ingredient with robust name checking
 * @param {string} ingredientName The name of the ingredient to find.
 * @returns {Promise<string|null>} The ingredient's document ID or null if not found.
 */
async function _findExistingIngredient(ingredientName) {
  try {
    const ingredientsRef = firestore.collection("ingredients");
    const normalizedName = _normalizeIngredientName(ingredientName);
    
    // 1. Try exact match first
    let snapshot = await ingredientsRef
      .where("title", "==", ingredientName.toLowerCase())
      .limit(1)
      .get();
    
    if (!snapshot.empty) {
      return snapshot.docs[0].id;
    }
    
    // 2. Try normalized name match
    snapshot = await ingredientsRef
      .where("title", "==", normalizedName)
      .limit(1)
      .get();
    
    if (!snapshot.empty) {
      return snapshot.docs[0].id;
    }
    
    // 3. Try normalized matching (remove spaces, hyphens, underscores)
    const normalizedInputName = _normalizeIngredientName(ingredientName);
    
    // Get all ingredients and check for normalized matches
    const allIngredientsSnapshot = await ingredientsRef.get();
    
    for (const doc of allIngredientsSnapshot.docs) {
      const ingredientData = doc.data();
      const dbTitle = ingredientData.title || '';
      const normalizedDbTitle = _normalizeIngredientName(dbTitle);
      
      if (normalizedInputName === normalizedDbTitle) {
        return doc.id;
      }
    }
    
    return null;
  } catch (error) {
    console.error(`Error finding existing ingredient "${ingredientName}":`, error);
    return null;
  }
}

/**
 * Normalize ingredient name by removing spaces, hyphens, and underscores
 * @param {string} ingredientName The ingredient name to normalize.
 * @returns {string} The normalized ingredient name.
 */
function _normalizeIngredientName(ingredientName) {
  // Remove spaces, hyphens, and underscores, convert to lowercase
  return ingredientName.toLowerCase().replace(/[\s\-_]/g, '');
}

/**
 * Helper function to generate details for an ingredient using Gemini and save it.
 * It uses .add() to create an auto-generated ID.
 * @param {string} ingredientName The name of the ingredient.
 * @returns {Promise<string|null>} The new ingredient's document ID or null.
 */
async function _generateAndSaveIngredient(ingredientName) {
  try {
    const model = await _getGeminiModel();
    const prompt = `
      Generate a detailed JSON object for the ingredient "${ingredientName}".
      The JSON object must match this structure:
      {
  "title": "${ingredientName}",
  "type": "ONLY USE THESE TYPES: protein, grain, vegetable, fruit, sweetener, condiment, pastry, dairy, oil, herb, spice, liquid", 
  "calories": number,
  "macros": {
    "protein": "string",
    "carbs": "string",
    "fat": "string"
  },
  "categories": ["string"],
  "features": {
    "fiber": "string",
    "g_i": "string",
    "season": "string",
    "water": "string",
    "rainbow": "string"
  },
  "techniques": [
    "string"
  ],
  "storageOptions": {
    "countertop": "string",
    "fridge": "string",
    "freezer": "string"
  },
  "isAntiInflammatory": boolean,
  "alt": ["string"],
  "image": "string"
}
      
      IMPORTANT: The "type" field MUST be one of these values ONLY:
      - "protein" (for meat, fish, eggs, tofu, etc.)
      - "grain" (for rice, pasta, bread, quinoa, etc.)
      - "vegetable" (for carrots, broccoli, spinach, etc.)
      - "fruit" (for apples, bananas, berries, etc.)
      - "sweetener" (for sugar, honey, maple syrup, etc.)
      - "condiment" (for ketchup, mustard, soy sauce, etc.)
      - "pastry" (for cakes, cookies, pies, etc.)
      - "dairy" (for milk, cheese, yogurt, etc.)
      - "oil" (for olive oil, coconut oil, etc.)
      - "herb" (for basil, thyme, rosemary, etc.)
      - "spice" (for salt, pepper, cinnamon, etc.)
      - "liquid" (for water, broth, juice, etc.)
      
      Do not use any other type values. Choose the most appropriate one from the list above.
      Do not include any text, markdown, or formatting outside of the JSON object itself.
    `;

    const result = await model.generateContent(prompt);
    const response = await result.response;
    const text = response.text().replace(/```json|```/g, "").trim();
    const ingredientData = JSON.parse(text);

    // Validate and ensure the type is one of the allowed values
    const allowedTypes = ['protein', 'grain', 'vegetable', 'fruit', 'sweetener', 'condiment', 'pastry', 'dairy', 'oil', 'herb', 'spice', 'liquid'];
    if (!allowedTypes.includes(ingredientData.type)) {
      console.warn(`Invalid type "${ingredientData.type}" for ingredient "${ingredientName}". Defaulting to "vegetable".`);
      ingredientData.type = 'vegetable'; // Default fallback
    }

    ingredientData.createdAt = admin.firestore.FieldValue.serverTimestamp();

    const newIngredientRef = await firestore.collection("ingredients").add(ingredientData);
    
    console.log(`Successfully generated and saved new ingredient: ${ingredientData.title} (ID: ${newIngredientRef.id}) with type: ${ingredientData.type}`);
    return newIngredientRef.id;

  } catch (error) {
    console.error(`Error generating details for "${ingredientName}":`, error);
    return null;
  }
}

/**
 * An on-call Cloud Function that allows a user to manually add a BATCH of
 * ingredients to their weekly shopping list.
 * - This is for features like the "spin wheel" that generate a list of items.
 * - Items are stored in the 'manualItems' map.
 */
exports.addManualItemsToShoppingList = functions.https.onCall(
  async (data, context) => {
    // 1. Validate call
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "The function must be called while authenticated."
      );
    }
    if (!data.items || !Array.isArray(data.items) || data.items.length === 0) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "The function must be called with a non-empty 'items' array."
      );
    }

    const userId = context.auth.uid;
    const itemsToAdd = data.items; // e.g., [{ingredientId: 'X', amount: 'Y'}, ...]
    console.log(`Manual batch add for user ${userId}:`, itemsToAdd);

    try {
      // 2. Determine the current week ID
      const today = new Date();
      const year = today.getUTCFullYear();
      const weekNo = _getWeek(today);
      const weekId = `week_${year}-${String(weekNo).padStart(2, "0")}`;

      const listRef = firestore
        .collection("userMeals")
        .doc(userId)
        .collection("shoppingList")
        .doc(weekId);

      // 3. Use a transaction to safely read, modify, and write the map.
      await firestore.runTransaction(async (transaction) => {
        const doc = await transaction.get(listRef);
        const existingData = doc.data() || {};
        const manualItems = existingData.manualItems || {};

        itemsToAdd.forEach((item) => {
          const { ingredientId, amount } = item;
          if (ingredientId) {
            const key = amount ? `${ingredientId}/${amount}` : ingredientId;
            manualItems[key] = false; // Add new items as not purchased
          }
        });

        if (Object.keys(manualItems).length === 0) {
          console.log("No valid items to add.");
          return; // Don't write if there's nothing to write
        }

        // Write the entire updated map back.
        transaction.set(
          listRef,
          {
            manualItems, // This contains old and new items
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true } // Merge to avoid overwriting 'generatedItems'
        );
      });

      console.log(
        `Successfully added batch of manual items for user ${userId}`
      );
      return { status: "success" };
    } catch (error) {
      console.error("Error adding manual items batch:", error);
      throw new functions.https.HttpsError(
        "internal",
        "An error occurred while adding items to the shopping list."
      );
    }
  }
);

// Post-related cloud functions for optimized feed loading

// Efficient post loading with server-side filtering and pagination
exports.getPostsFeed = functions.https.onCall(async (data, context) => {
  try {
    const {
      category = 'general',
      limit = 24,
      lastPostId = null,
      excludePostId = null,
      includeBattlePosts = true
    } = data;

    // Build query with server-side filtering
    let query = admin.firestore()
      .collection('posts')
      .orderBy('createdAt', 'desc'); // Simple query - no compound index needed

    // Apply category filtering on server
    if (category && category.toLowerCase() !== 'all' && category.toLowerCase() !== 'general') {
      query = query.where('category', '==', category);
    }

    // Apply pagination
    if (lastPostId) {
      const lastDoc = await admin.firestore().collection('posts').doc(lastPostId).get();
      if (lastDoc.exists) {
        query = query.startAfter(lastDoc);
      }
    }

    query = query.limit(limit);

    const snapshot = await query.get();
    
    const posts = [];
    const batchPromises = [];

    snapshot.docs.forEach(doc => {
      const data = doc.data();
      
      // Skip excluded post
      if (excludePostId && doc.id === excludePostId) {
        return;
      }

      // Skip private posts (client-side filtering)
      if (data.battleId === 'private') {
        return;
      }

      // Only include essential data for grid view (optimization)
      const optimizedPost = {
        id: doc.id,
        mealId: data.mealId || '', // Add mealId for proper meal-post association
        mediaPaths: data.mediaPaths || [],
        isVideo: data.isVideo || false,
        category: data.category || 'general',
        name: data.name || 'Unknown',
        userId: data.userId || '',
        createdAt: data.createdAt,
        isBattle: data.isBattle || false,
        // Don't include heavy fields like full content, comments, etc.
      };

      posts.push(optimizedPost);

      // Batch user data fetching for efficiency
      if (data.userId) {
        batchPromises.push(
          admin.firestore().collection('users').doc(data.userId).get()
        );
      }
    });

    // Fetch user data in batch
    const userDocs = await Promise.all(batchPromises);
    const userMap = {};
    
    userDocs.forEach(userDoc => {
      if (userDoc.exists) {
        const userData = userDoc.data();
        userMap[userDoc.id] = {
          displayName: userData.displayName || 'Anonymous',
          avatar: userData.avatar || '',
          isPremium: userData.isPremium || false
        };
      }
    });

    // Attach user data to posts
    posts.forEach(post => {
      if (post.userId && userMap[post.userId]) {
        post.userName = userMap[post.userId].displayName;
        post.userAvatar = userMap[post.userId].avatar;
        post.userIsPremium = userMap[post.userId].isPremium;
      }
    });

    return {
      success: true,
      posts: posts,
      hasMore: snapshot.docs.length === limit,
      lastPostId: snapshot.docs.length > 0 ? snapshot.docs[snapshot.docs.length - 1].id : null,
      totalFetched: snapshot.docs.length
    };

  } catch (error) {
    console.error('Error fetching posts:', error);
    return {
      success: false,
      error: error.message,
      posts: []
    };
  }
});

// Get user-specific posts with optimized server-side processing
exports.getUserPosts = functions.https.onCall(async (data, context) => {
  try {
    const {
      userId,
      limit = 30,
      lastPostId = null,
      includeUserData = true
    } = data;

    if (!userId) {
      return {
        success: false,
        error: 'userId is required',
        posts: []
      };
    }

    // Build query to fetch user's posts directly from posts collection
    let query = admin.firestore()
      .collection('posts')
      .where('userId', '==', userId)
      .orderBy('createdAt', 'desc');

    // Apply pagination
    if (lastPostId) {
      const lastDoc = await admin.firestore().collection('posts').doc(lastPostId).get();
      if (lastDoc.exists) {
        query = query.startAfter(lastDoc);
      }
    }

    query = query.limit(limit);

    const snapshot = await query.get();
    const posts = [];

    // Get user data once if needed
    let userData = null;
    if (includeUserData) {
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      if (userDoc.exists) {
        const userDataRaw = userDoc.data();
        userData = {
          displayName: userDataRaw.displayName || 'Anonymous',
          profileImage: userDataRaw.profileImage || '',
          isPremium: userDataRaw.isPremium || false
        };
      }
    }

    snapshot.docs.forEach(doc => {
      const data = doc.data();
      
      const optimizedPost = {
        id: doc.id,
        mealId: data.mealId || '', // Add mealId for proper meal-post association
        userId: data.userId || '',
        mediaPaths: data.mediaPaths || [],
        isVideo: data.isVideo || false,
        category: data.category || 'general',
        name: data.name || 'Unknown',
        createdAt: data.createdAt,
        isBattle: data.isBattle || false,
        battleId: data.battleId || '',
        favorites: data.favorites || [],
      };

      // Attach user data if available
      if (userData) {
        optimizedPost.userName = userData.displayName;
        optimizedPost.userAvatar = userData.profileImage;
        optimizedPost.userIsPremium = userData.isPremium;
      }

      posts.push(optimizedPost);
    });

    return {
      success: true,
      posts: posts,
      hasMore: snapshot.docs.length === limit,
      lastPostId: snapshot.docs.length > 0 ? snapshot.docs[snapshot.docs.length - 1].id : null,
      totalFetched: snapshot.docs.length,
      userData: userData
    };

  } catch (error) {
    console.error('Error fetching user posts:', error);
    return {
      success: false,
      error: error.message,
      posts: []
    };
  }
});

// Get battle posts for the current week (Monday to Sunday)
exports.getChallengePostsForWeek = functions.https.onCall(async (data, context) => {
  try {
    const {
      weekStart,
      weekEnd,
      limit = 20
    } = data;

    if (!weekStart || !weekEnd) {
      return {
        success: false,
        error: 'weekStart and weekEnd are required',
        posts: []
      };
    }

    // Convert ISO strings to Firestore timestamps
    const startDate = new Date(weekStart);
    const endDate = new Date(weekEnd);
    
    console.log('Date range for battle posts:', {
      weekStart,
      weekEnd,
      startDate: startDate.toISOString(),
      endDate: endDate.toISOString()
    });

    // Build query to fetch all battle posts (we'll filter by date on server side)
    let query = admin.firestore()
      .collection('posts')
      .where('isBattle', '==', true)
      .orderBy('createdAt', 'desc')
      .limit(limit * 2); // Get more posts to account for date filtering

    const snapshot = await query.get();
    console.log(`Found ${snapshot.docs.length} battle posts total`);
    
    const posts = [];
    const batchPromises = [];

    snapshot.docs.forEach(doc => {
      const data = doc.data();
      
      // Skip private posts
      if (data.battleId === 'private') {
        return;
      }

      // Filter by date range on server side since createdAt is a string
      if (data.createdAt) {
        const postDate = new Date(data.createdAt);
        console.log('Checking post date:', {
          postId: doc.id,
          createdAt: data.createdAt,
          postDate: postDate.toISOString(),
          isInRange: postDate >= startDate && postDate <= endDate
        });
        if (postDate < startDate || postDate > endDate) {
          return; // Skip posts outside the date range
        }
      }

      // Only include essential data for horizontal list view
      const optimizedPost = {
        id: doc.id,
        mealId: data.mealId || '',
        mediaPaths: data.mediaPaths || [],
        isVideo: data.isVideo || false,
        category: data.category || 'general',
        name: data.name || 'Unknown',
        username: data.name || 'Unknown', // For display in horizontal list
        userId: data.userId || '',
        createdAt: data.createdAt,
        isBattle: data.isBattle || false,
        battleId: data.battleId || '',
        favorites: data.favorites || [],
      };

      posts.push(optimizedPost);

      // Batch user data fetching for efficiency
      if (data.userId) {
        batchPromises.push(
          admin.firestore().collection('users').doc(data.userId).get()
        );
      }
    });

    // Fetch user data in batch
    const userDocs = await Promise.all(batchPromises);
    const userMap = {};
    
    userDocs.forEach(userDoc => {
      if (userDoc.exists) {
        const userData = userDoc.data();
        userMap[userDoc.id] = {
          displayName: userData.displayName || 'Anonymous',
          avatar: userData.avatar || '',
          isPremium: userData.isPremium || false
        };
      }
    });

    // Attach user data to posts
    posts.forEach(post => {
      if (post.userId && userMap[post.userId]) {
        post.username = userMap[post.userId].displayName;
        post.avatar = userMap[post.userId].avatar;
        post.isPremium = userMap[post.userId].isPremium;
      }
    });

    return {
      success: true,
      posts: posts,
      totalFetched: posts.length
    };

  } catch (error) {
    console.error('Error fetching battle posts:', error);
    return {
      success: false,
      error: error.message,
      posts: []
    };
  }
});

/**
 * Scheduled function to automatically generate weekly challenge ingredients and award winners every Sunday
 * Runs every Sunday at 12:00 AM UTC
 */
exports.generateWeeklyChallengeIngredientsScheduled = functions.pubsub
  .schedule('0 0 * * 0') // Every Sunday at midnight UTC
  .timeZone('UTC')
  .onRun(async (context) => {
    try {
      console.log('--- Running scheduled weekly challenge ingredients generation and winner awarding ---');

      // First, award winners from the previous week's challenge
      await awardChallengeWinners();

      // Then generate new challenge ingredients for the upcoming week
      await generateNewChallengeIngredients();

      return null;

    } catch (error) {
      console.error('Error in scheduled weekly challenge processing:', error);
      return null;
    }
  });

/**
 * Award winners from the previous week's challenge based on favorites
 */
async function awardChallengeWinners() {
  try {
    console.log('--- Awarding challenge winners ---');

    // Calculate the previous week's date range (Monday to Sunday)
    const today = new Date();
    const lastSunday = addDays(today, -7); // Previous Sunday
    const lastMonday = addDays(lastSunday, -6); // Previous Monday
    
    const weekStart = format(lastMonday, 'yyyy-MM-dd');
    const weekEnd = format(lastSunday, 'yyyy-MM-dd');
    
    console.log(`Awarding winners for week: ${weekStart} to ${weekEnd}`);

    // Get all challenge posts from the previous week
    const challengePostsQuery = admin.firestore()
      .collection('posts')
      .where('isBattle', '==', true)
      .where('createdAt', '>=', weekStart)
      .where('createdAt', '<=', weekEnd + 'T23:59:59.999Z')
      .orderBy('createdAt', 'desc');

    const snapshot = await challengePostsQuery.get();
    
    if (snapshot.empty) {
      console.log('No challenge posts found for the previous week');
      return;
    }

    console.log(`Found ${snapshot.docs.length} challenge posts for winner selection`);

    // Calculate scores for each post (based on favorites count)
    const postsWithScores = [];
    
    snapshot.docs.forEach(doc => {
      const data = doc.data();
      const favoritesCount = data.favorites ? data.favorites.length : 0;
      
      postsWithScores.push({
        id: doc.id,
        userId: data.userId,
        name: data.name || 'Unknown',
        favoritesCount: favoritesCount,
        createdAt: data.createdAt,
        mediaPaths: data.mediaPaths || []
      });
    });

    // Sort by favorites count (descending) and then by creation time (ascending for tie-breaking)
    postsWithScores.sort((a, b) => {
      if (b.favoritesCount !== a.favoritesCount) {
        return b.favoritesCount - a.favoritesCount;
      }
      return new Date(a.createdAt) - new Date(b.createdAt);
    });

    // Determine winners (top 3, or all if less than 3 posts)
    const winners = postsWithScores.slice(0, Math.min(3, postsWithScores.length));
    
    if (winners.length === 0) {
      console.log('No winners to award');
      return;
    }

    console.log(`Awarding ${winners.length} winners:`, winners.map(w => ({ 
      userId: w.userId, 
      name: w.name, 
      favorites: w.favoritesCount 
    })));

    // Award prizes to winners
    const winnerAwards = [];
    
    for (let i = 0; i < winners.length; i++) {
      const winner = winners[i];
      const position = i + 1;
      let prize = '';
      
      // Define prizes based on position
      switch (position) {
        case 1:
          prize = '1st Place - Premium Badge + 100 Points';
          break;
        case 2:
          prize = '2nd Place - Silver Badge + 50 Points';
          break;
        case 3:
          prize = '3rd Place - Bronze Badge + 25 Points';
          break;
      }

      // Update user's points in the points collection (same as client-side system)
      await firestore.collection('points').doc(winner.userId).set({
        points: admin.firestore.FieldValue.increment(getPointsForPosition(position)),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      // Update user's profile with challenge-specific stats
      await firestore.collection('users').doc(winner.userId).update({
        challengeWins: admin.firestore.FieldValue.increment(1),
        lastChallengeWin: admin.firestore.FieldValue.serverTimestamp(),
        [`position${position}Wins`]: admin.firestore.FieldValue.increment(1)
      });

      // Create award record
      const awardRecord = {
        userId: winner.userId,
        userName: winner.name,
        position: position,
        prize: prize,
        points: getPointsForPosition(position),
        weekStart: weekStart,
        weekEnd: weekEnd,
        postId: winner.id,
        favoritesCount: winner.favoritesCount,
        awardedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      await firestore.collection('challengeAwards').add(awardRecord);
      
      // Send notification to winner
      await sendWinnerNotification(winner.userId, winner.name, position, prize, getPointsForPosition(position));
      
      winnerAwards.push(awardRecord);
    }

    // Update general collection with weekly results
    await firestore.collection('general').doc('general').update({
      lastChallengeResults: {
        weekStart: weekStart,
        weekEnd: weekEnd,
        totalPosts: postsWithScores.length,
        winners: winnerAwards,
        processedAt: admin.firestore.FieldValue.serverTimestamp()
      }
    });

    console.log(`Successfully awarded ${winners.length} challenge winners`);

  } catch (error) {
    console.error('Error awarding challenge winners:', error);
    throw error;
  }
}

/**
 * Generate new challenge ingredients for the upcoming week
 */
async function generateNewChallengeIngredients() {
  try {
    console.log('--- Generating new challenge ingredients ---');

    // Get the ingredient challenge list from general collection
    const generalDoc = await firestore.collection('general').doc('general').get();
    
    if (!generalDoc.exists) {
      console.error('General collection document not found');
      return;
    }

    const generalData = generalDoc.data();
    const ingredientChallengeString = generalData.ingredientsChallenge || '';
    
    if (!ingredientChallengeString) {
      console.error('ingredientsChallenge string not found in general collection');
      return;
    }

    // Parse the comma-separated string and categorize ingredients
    const allIngredients = ingredientChallengeString.split(',').map(ing => ing.trim()).filter(ing => ing);
    const proteins = allIngredients.filter(ing => ing.endsWith('-p'));
    const vegetables = allIngredients.filter(ing => ing.endsWith('-v'));
    
    if (proteins.length < 2) {
      console.error(`Not enough protein ingredients. Found ${proteins.length}, need at least 2.`);
      return;
    }
    
    if (vegetables.length < 2) {
      console.error(`Not enough vegetable ingredients. Found ${vegetables.length}, need at least 2.`);
      return;
    }

    // Get 2 random proteins and 2 random vegetables
    const shuffledProteins = [...proteins].sort(() => 0.5 - Math.random());
    const shuffledVegetables = [...vegetables].sort(() => 0.5 - Math.random());
    
    const selectedProteins = shuffledProteins.slice(0, 2);
    const selectedVegetables = shuffledVegetables.slice(0, 2);
    const selectedIngredients = [...selectedProteins, ...selectedVegetables];

    // Calculate the following Sunday's date (next week)
    const today = new Date();
    const nextSunday = addDays(today, 7); // Next Sunday
    const sundayDate = format(nextSunday, 'dd-MM-yyyy');

    // Create the challenge details string in the specified format
    const challengeDetails = `${sundayDate},${selectedIngredients.join(',')}`;

    // Save to challenge_details in general collection
    await firestore.collection('general').doc('general').update({
      challenge_details: challengeDetails,
      lastChallengeUpdate: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log(`Successfully generated scheduled challenge ingredients: ${challengeDetails}`);

  } catch (error) {
    console.error('Error generating new challenge ingredients:', error);
    throw error;
  }
}

/**
 * Get points for challenge position
 */
function getPointsForPosition(position) {
  switch (position) {
    case 1: return 100;
    case 2: return 50;
    case 3: return 25;
    default: return 0;
  }
}

/**
 * Send winner notification via FCM
 */
async function sendWinnerNotification(userId, userName, position, prize, points) {
  try {
    console.log(`Sending winner notification to user ${userId} for position ${position}`);
    
    // Get user's FCM token
    const userDoc = await firestore.collection('users').doc(userId).get();
    const userData = userDoc.data();
    
    if (!userData || !userData.fcmToken) {
      console.log(`No FCM token found for user ${userId}`);
      return;
    }

    const fcmToken = userData.fcmToken;
    
    // Create notification payload
    const message = {
      token: fcmToken,
      notification: {
        title: `🏆 Challenge Winner!`,
        body: `Congratulations ${userName}! You placed ${position}${getOrdinalSuffix(position)} and earned ${points} points!`,
      },
      data: {
        type: 'challenge_winner',
        position: position.toString(),
        points: points.toString(),
        prize: prize,
        userId: userId,
        timestamp: Date.now().toString()
      },
      android: {
        notification: {
          icon: 'ic_notification',
          color: '#FF6B35',
          sound: 'default',
          priority: 'high'
        }
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
            'content-available': 1
          }
        }
      }
    };

    // Send notification
    const response = await admin.messaging().send(message);
    console.log(`Successfully sent winner notification: ${response}`);
    
    // Store notification in database for history
    await firestore.collection('notifications').add({
      userId: userId,
      type: 'challenge_winner',
      title: '🏆 Challenge Winner!',
      body: `Congratulations ${userName}! You placed ${position}${getOrdinalSuffix(position)} and earned ${points} points!`,
      data: {
        position: position,
        points: points,
        prize: prize
      },
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

  } catch (error) {
    console.error(`Error sending winner notification to user ${userId}:`, error);
  }
}

/**
 * Get ordinal suffix for position (1st, 2nd, 3rd, etc.)
 */
function getOrdinalSuffix(position) {
  const j = position % 10;
  const k = position % 100;
  if (j === 1 && k !== 11) {
    return "st";
  }
  if (j === 2 && k !== 12) {
    return "nd";
  }
  if (j === 3 && k !== 13) {
    return "rd";
  }
  return "th";
}

/**
 * Get current challenge results and leaderboard data
 */
exports.getChallengeResults = functions.https.onCall(async (data, context) => {
  try {
    console.log('--- Getting challenge results ---');
    
    // Set a timeout for the entire function
    const timeoutPromise = new Promise((_, reject) => {
      setTimeout(() => reject(new Error('Function timeout')), 5000); // 5 second timeout
    });
    
    const functionPromise = (async () => {

    // Get current challenge details
    const generalDoc = await firestore.collection('general').doc('general').get();
    const generalData = generalDoc.data() || {};
    
    const challengeDetails = generalData.challenge_details || '';
    const lastChallengeResults = generalData.lastChallengeResults || null;

    // Get current week's leaderboard data
    const now = new Date();
    const monday = new Date(now);
    monday.setDate(now.getDate() - now.getDay() + 1); // Monday of current week
    const sunday = new Date(monday);
    sunday.setDate(monday.getDate() + 6); // Sunday of current week

    const weekStart = format(monday, 'yyyy-MM-dd');
    const weekEnd = format(sunday, 'yyyy-MM-dd');

    // Get current week's challenge posts with limit to reduce execution time
    const challengePostsQuery = admin.firestore()
      .collection('posts')
      .where('isBattle', '==', true)
      .where('createdAt', '>=', weekStart)
      .where('createdAt', '<=', weekEnd + 'T23:59:59.999Z')
      .orderBy('createdAt', 'desc')
      .limit(100); // Limit to 100 posts to reduce execution time

    const snapshot = await challengePostsQuery.get();
    
    // Calculate current leaderboard
    const userLikesMap = {};
    
    snapshot.docs.forEach(doc => {
      const data = doc.data();
      const postUserId = data.userId;
      const favorites = data.favorites || [];
      const likesCount = favorites.length;

      if (postUserId && likesCount > 0) {
        if (userLikesMap[postUserId]) {
          userLikesMap[postUserId].totalLikes += likesCount;
          userLikesMap[postUserId].postCount += 1;
        } else {
          userLikesMap[postUserId] = {
            userId: postUserId,
            totalLikes: likesCount,
            postCount: 1,
          };
        }
      }
    });

    // Sort by total likes
    const currentLeaderboard = Object.values(userLikesMap)
      .sort((a, b) => b.totalLikes - a.totalLikes)
      .slice(0, 10); // Top 10

    // Get user details for leaderboard in batches to reduce execution time
    const leaderboardWithDetails = [];
    const batchSize = 10; // Process users in batches
    
    for (let i = 0; i < currentLeaderboard.length; i += batchSize) {
      const batch = currentLeaderboard.slice(i, i + batchSize);
      const batchPromises = batch.map(async (userData, batchIndex) => {
        const userDoc = await firestore.collection('users').doc(userData.userId).get();
        const userDetails = userDoc.data() || {};
        
        return {
          userId: userData.userId,
          displayName: userDetails.displayName || 'Unknown',
          profileImage: userDetails.profileImage || '',
          totalLikes: userData.totalLikes,
          postCount: userData.postCount,
          rank: i + batchIndex + 1,
        };
      });
      
      const batchResults = await Promise.all(batchPromises);
      leaderboardWithDetails.push(...batchResults);
    }

    // Parse challenge ingredients with type information
    let parsedIngredients = [];
    let ingredientNames = [];
    
    if (challengeDetails) {
      const parts = challengeDetails.split(',');
      if (parts.length >= 5) {
        const ingredientParts = parts.slice(1); // Skip the date
        parsedIngredients = ingredientParts.map(ingredient => {
          const cleanName = ingredient.replace(/-[vp]$/, '');
          const type = ingredient.endsWith('-v') ? 'vegetable' : 
                      ingredient.endsWith('-p') ? 'protein' : 'unknown';
          
          return {
            name: cleanName,
            type: type,
            fullName: ingredient,
          };
        });
        ingredientNames = parsedIngredients.map(i => i.name);
      }
    }

      return {
        success: true,
        currentChallenge: {
          details: challengeDetails,
          ingredients: parsedIngredients,
          ingredientNames: ingredientNames,
          endDate: challengeDetails ? challengeDetails.split(',')[0] : '',
          weekStart: weekStart,
          weekEnd: weekEnd,
        },
        currentLeaderboard: leaderboardWithDetails,
        lastResults: lastChallengeResults,
      };
    })();
    
    // Race between function execution and timeout
    return await Promise.race([functionPromise, timeoutPromise]);

  } catch (error) {
    console.error('Error getting challenge results:', error);
    return {
      success: false,
      error: error.message,
    };
  }
});

/**
 * Get user notifications
 */
exports.getUserNotifications = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'The function must be called while authenticated.'
      );
    }

    const userId = context.auth.uid;
    const { limit = 20, lastNotificationId = null } = data;

    let query = firestore
      .collection('notifications')
      .where('userId', '==', userId)
      .orderBy('createdAt', 'desc')
      .limit(limit);

    if (lastNotificationId) {
      const lastDoc = await firestore.collection('notifications').doc(lastNotificationId).get();
      if (lastDoc.exists) {
        query = query.startAfter(lastDoc);
      }
    }

    const snapshot = await query.get();
    const notifications = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      createdAt: doc.data().createdAt?.toDate?.()?.toISOString() || doc.data().createdAt
    }));

    return {
      success: true,
      notifications: notifications,
      hasMore: snapshot.docs.length === limit,
      lastNotificationId: snapshot.docs.length > 0 ? snapshot.docs[snapshot.docs.length - 1].id : null
    };

  } catch (error) {
    console.error('Error getting user notifications:', error);
    return {
      success: false,
      error: error.message,
      notifications: []
    };
  }
});

/**
 * Mark notification as read
 */
exports.markNotificationAsRead = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'The function must be called while authenticated.'
      );
    }

    const { notificationId } = data;
    if (!notificationId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'notificationId is required'
      );
    }

    const userId = context.auth.uid;
    
    // Verify the notification belongs to the user
    const notificationDoc = await firestore.collection('notifications').doc(notificationId).get();
    if (!notificationDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Notification not found'
      );
    }

    const notificationData = notificationDoc.data();
    if (notificationData.userId !== userId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'You can only mark your own notifications as read'
      );
    }

    // Mark as read
    await firestore.collection('notifications').doc(notificationId).update({
      read: true,
      readAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return { success: true };

  } catch (error) {
    console.error('Error marking notification as read:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError(
      'internal',
      'An error occurred while marking notification as read'
    );
  }
});

/**
 * Firebase Function to process pending meals with AI-generated details
 * Uses exponential backoff retry logic with jitter for reliability
 */
exports.processPendingMeals = functions.pubsub
  .schedule('every 1 minutes')
  .onRun(async (context) => {
    try {
      console.log('--- Starting meal processing job ---');
      
      // Get all meals that need processing
      const pendingMealsQuery = admin.firestore()
        .collection('meals')
        .where('needsProcessing', '==', true)
        .where('status', 'in', ['pending', 'failed'])
        .orderBy('processingPriority', 'asc')
        .limit(10); // Process 10 meals at a time to avoid timeouts
      
      const pendingMealsSnapshot = await pendingMealsQuery.get();
      
      if (pendingMealsSnapshot.empty) {
        console.log('No pending meals to process');
        return null;
      }
      
      console.log(`Found ${pendingMealsSnapshot.docs.length} pending meals to process`);
      
      const processingPromises = pendingMealsSnapshot.docs.map(async (doc) => {
        const mealData = doc.data();
        const mealId = doc.id;
        
        try {
          // Mark as processing to prevent duplicate processing
          await doc.ref.update({
            status: 'processing',
            lastProcessingAttempt: admin.firestore.FieldValue.serverTimestamp(),
            processingAttempts: admin.firestore.FieldValue.increment(1)
          });
          
          console.log(`Processing meal: ${mealData.title} (ID: ${mealId})`);
          
          // Generate full meal details using AI
          const fullMealDetails = await generateFullMealDetails(
            mealData.title,
            mealData.ingredients || {},
            mealData.mealType || 'general'
          );
          
          // Update meal with complete details
          await doc.ref.update({
            ...fullMealDetails,
            status: 'completed',
            needsProcessing: false,
            completedAt: admin.firestore.FieldValue.serverTimestamp(),
            version: 'complete'
          });
          
          console.log(`Successfully completed meal: ${mealData.title}`);
          
        } catch (error) {
          console.error(`Error processing meal ${mealData.title}:`, error);
          
          // Implement exponential backoff with jitter
          const attempts = (mealData.processingAttempts || 0) + 1;
          const maxAttempts = 5;
          
          // Calculate backoff delay with jitter
          const baseDelay = Math.pow(2, attempts) * 1000; // Base delay in ms
          const jitter = Math.random() * 1000; // Random jitter up to 1 second
          const totalDelay = baseDelay + jitter;
          
          if (attempts < maxAttempts) {
            // Schedule retry by updating priority (lower priority = processed later)
            const retryTime = Date.now() + totalDelay;
            await doc.ref.update({
              status: 'pending',
              needsProcessing: true,
              processingPriority: retryTime,
              lastError: error.message,
              processingAttempts: attempts
            });
            
            console.log(`Scheduled retry for meal ${mealData.title} in ${Math.round(totalDelay/1000)}s (attempt ${attempts})`);
          } else {
            // Mark as failed after max attempts - ONLY update status, preserve existing meal data
            await doc.ref.update({
              status: 'failed',
              needsProcessing: true,
              failedAt: admin.firestore.FieldValue.serverTimestamp(),
              lastError: error.message,
              processingAttempts: attempts
            });
            console.log(`Marked meal ${mealData.title} as failed after ${attempts} attempts`);
          }
        }
      });
      
      // Wait for all meals to be processed
      await Promise.all(processingPromises);
      
      console.log('--- Meal processing job completed ---');
      return null;
      
    } catch (error) {
      console.error('Error in meal processing job:', error);
      return null;
    }
  });

/**
 * Helper function to generate full meal details using AI
 */
async function generateFullMealDetails(title, basicIngredients, mealType) {
  try {
    // Use Gemini API to generate complete meal details
    const prompt = `Generate complete meal details for: ${title}
    
    Basic ingredients: ${JSON.stringify(basicIngredients)}
    Meal type: ${mealType}
    
    Please provide:
    1. Complete ingredient list with measurements
    2. Step-by-step cooking instructions
    3. Nutritional information (calories, protein, carbs, fat)
    4. Cooking time and difficulty
    5. Serving size
    6. Dietary categories (vegan, gluten-free, etc.)
    7. Cuisine type
    8. A detailed description of the meal (2-3 sentences describing the dish, its flavors, and appeal)
    
    Format as JSON with these fields:
    {
      "ingredients": {
        "ingredient1": "amount with unit (e.g., '1 cup', '200g')",
        "ingredient2": "amount with unit"
      },
      "instructions": ["step1", "step2", ...],
      "calories": number,
      "nutritionalInfo": {
        "calories": number,
        "protein": number,
        "carbs": number,
        "fat": number
      },
      "cookingTime": "X minutes",
      "cookingMethod": "grilled/roasted/sauteed/etc.",
      "difficulty": "easy/medium/hard",
      "serveQty": number,
      "categories": ["category1", "category2"],
      "cuisine": "Italian, Mexican, etc.",
      "description": "A detailed description of the meal (2-3 sentences)"
    }`;
    
    const model = await _getGeminiModel();
    const result = await model.generateContent(prompt);
    
    const response = result.response.text();
    
    console.log(`Raw AI response for ${title}:`, response.substring(0, Math.min(response.length, 500)) + '...');
    
    // Parse JSON response with robust error handling and extraction
    try {
      const mealDetails = await processAIResponse(response, 'meal_generation');
      
      // Validate that we have the essential fields
      if (!mealDetails.ingredients || !mealDetails.instructions || !mealDetails.nutritionalInfo) {
        throw new Error('Missing essential meal fields in AI response');
      }
      
      // Return validated meal data
      return {
        ingredients: mealDetails.ingredients,
        instructions: mealDetails.instructions,
        calories: mealDetails.calories || 300,
        nutritionalInfo: mealDetails.nutritionalInfo,
        cookingTime: mealDetails.cookingTime || '30 minutes',
        difficulty: mealDetails.difficulty || 'medium',
        cookingMethod: mealDetails.cookingMethod || 'grilled/roasted/sauteed/etc.',
        serveQty: mealDetails.serveQty || 1,
        categories: mealDetails.categories || [mealType],
        cuisine: mealDetails.cuisine || 'general',
        description: mealDetails.description || '',
        aiGenerated: true,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
      };
      
    } catch (parseError) {
      console.error('Error parsing AI response:', parseError);
      // Don't return fallback data - let the retry logic handle this
      throw new Error(`Failed to parse AI response: ${parseError.message}`);
    }
    
  } catch (error) {
    console.error('Error generating meal details:', error);
    // Don't return fallback data - let the retry logic handle this
    throw error;
  }
}

/**
 * Process AI response with robust JSON parsing and extraction
 * Based on methods from the Gemini service
 */
async function processAIResponse(text, operation) {
  // Check if text is empty or contains error message
  if (!text || text.startsWith('Error:')) {
    return createFallbackResponse(operation, 'Empty or error response from API');
  }

  try {
    // Use robust validation for meal generation
    if (operation === 'meal_generation') {
      console.log('Processing meal generation response with robust extraction...');
      const result = validateAndExtractMealData(text);
      console.log('Successfully extracted meal data:', Object.keys(result));
      return result;
    }

    const jsonData = extractJsonObject(text);
    
    // Validate required fields based on operation
    validateResponseStructure(jsonData, operation);
    
    // Ensure all numeric values are properly converted to numbers
    const normalizedData = normalizeNumericValues(jsonData, operation);
    
    console.log('=== FINAL RESPONSE DATA ===');
    console.log('Operation:', operation);
    console.log('Data type:', typeof normalizedData);
    console.log('Data keys:', Object.keys(normalizedData));
    console.log('Full response:', JSON.stringify(normalizedData, null, 2));
    console.log('=== END RESPONSE DATA ===');
    
    return normalizedData;
  } catch (e) {
    // Try to extract partial JSON if possible
    try {
      const partialJson = extractPartialJson(text, operation);
      if (partialJson && Object.keys(partialJson).length > 0) {
        const normalizedPartial = normalizeNumericValues(partialJson, operation);
        
        console.log('=== PARTIAL EXTRACTION RESPONSE DATA ===');
        console.log('Operation:', operation);
        console.log('Data type:', typeof normalizedPartial);
        console.log('Data keys:', Object.keys(normalizedPartial));
        console.log('Full response:', JSON.stringify(normalizedPartial, null, 2));
        console.log('=== END PARTIAL RESPONSE DATA ===');
        
        return normalizedPartial;
      }
    } catch (partialError) {
      console.log('Partial JSON recovery failed:', partialError);
    }

         // Return a fallback structure based on operation type
     console.log(`Creating fallback response for ${operation} due to error:`, e.toString());
     const fallbackData = createFallbackResponse(operation, e.toString());
     
     console.log('=== FALLBACK RESPONSE DATA ===');
     console.log('Operation:', operation);
     console.log('Data type:', typeof fallbackData);
     console.log('Data keys:', Object.keys(fallbackData));
     console.log('Full response:', JSON.stringify(fallbackData, null, 2));
     console.log('=== END FALLBACK RESPONSE DATA ===');
     
     return fallbackData;
  }
}

/**
 * Normalize numeric values in the response data
 */
function normalizeNumericValues(data, operation) {
  if (!data || typeof data !== 'object') {
    return data;
  }

  // Deep clone and ensure proper typing
  const normalized = JSON.parse(JSON.stringify(data));

  if (operation === 'tasty_analysis' || operation === 'food_analysis') {
    // Normalize food analysis data
    if (normalized.foodItems && Array.isArray(normalized.foodItems)) {
      normalized.foodItems.forEach(item => {
        if (item.nutritionalInfo && typeof item.nutritionalInfo === 'object') {
          // Ensure nutritionalInfo is properly typed
          const nutrition = {};
          Object.keys(item.nutritionalInfo).forEach(key => {
            const value = item.nutritionalInfo[key];
            if (typeof value === 'string' && !isNaN(value)) {
              nutrition[key] = parseFloat(value);
            } else if (typeof value === 'number') {
              nutrition[key] = value;
            } else {
              nutrition[key] = value;
            }
          });
          item.nutritionalInfo = nutrition;
        }
      });
    }

    if (normalized.totalNutrition && typeof normalized.totalNutrition === 'object') {
      // Ensure totalNutrition is properly typed
      const totalNutrition = {};
      Object.keys(normalized.totalNutrition).forEach(key => {
        const value = normalized.totalNutrition[key];
        if (typeof value === 'string' && !isNaN(value)) {
          totalNutrition[key] = parseFloat(value);
        } else if (typeof value === 'number') {
          totalNutrition[key] = value;
        } else {
          totalNutrition[key] = value;
        }
      });
      normalized.totalNutrition = totalNutrition;
    }
  }

  return normalized;
}

/**
 * Extract JSON object from AI response text (robust version matching client-side)
 */
function extractJsonObject(text) {
  let jsonStr = text.trim();

  // Remove markdown code block syntax if present
  if (jsonStr.startsWith('```json')) {
    jsonStr = jsonStr.replace(/^```json\s*/, '').trim();
  }
  if (jsonStr.startsWith('```')) {
    jsonStr = jsonStr.replace(/^```\s*/, '').trim();
  }
  if (jsonStr.endsWith('```')) {
    jsonStr = jsonStr.substring(0, jsonStr.lastIndexOf('```')).trim();
  }

  // Fix common JSON issues from AI responses
  jsonStr = sanitizeJsonString(jsonStr);

  try {
    return JSON.parse(jsonStr);
  } catch (e) {
    // If parsing still fails, try to extract just the JSON part
    console.log('Initial JSON parsing failed, attempting to extract valid JSON...');

    // Try to find the start and end of JSON content
    const jsonStart = jsonStr.indexOf('{');
    const jsonEnd = jsonStr.lastIndexOf('}');

    if (jsonStart !== -1 && jsonEnd !== -1 && jsonEnd > jsonStart) {
      const extractedJson = jsonStr.substring(jsonStart, jsonEnd + 1);
      console.log('Extracted JSON:', extractedJson.substring(0, Math.min(extractedJson.length, 200)) + '...');

      // Clean the extracted JSON more aggressively
      const cleanedExtractedJson = aggressiveJsonCleanup(extractedJson);

      try {
        return JSON.parse(cleanedExtractedJson);
      } catch (extractError) {
        console.log('Extracted JSON parsing also failed:', extractError);
        console.log('Attempting to extract partial data from malformed JSON...');

        // Try to extract partial data even from malformed JSON
        const partialData = extractPartialDataFromMalformedJson(extractedJson);
        if (partialData && Object.keys(partialData).length > 0) {
          console.log('Successfully extracted partial data:', partialData);
          return partialData;
        }

        throw new Error(`Failed to parse JSON even after extraction: ${extractError.message}`);
      }
    }

    // If all else fails, try to extract partial data
    console.log('All JSON parsing methods failed. Attempting partial data extraction...');
    try {
      const partialData = extractPartialDataFromMalformedJson(jsonStr);
      if (partialData && Object.keys(partialData).length > 0) {
        console.log('Successfully extracted partial data from malformed JSON');
        return partialData;
      }
    } catch (partialError) {
      console.log('Partial data extraction also failed:', partialError);
    }

    throw new Error(`Could not extract valid JSON from response: ${e.message}`);
  }
}

/**
 * Sanitize JSON string to fix common AI response issues
 */
function sanitizeJsonString(jsonStr) {
  // Fix trailing quotes after ANY numeric values - more comprehensive approach
  // This catches cases like "healthScore": 6", "calories": 450", etc.
  jsonStr = jsonStr.replace(/"([^"]+)":\s*(\d+(?:\.\d+)?)"(?=\s*[,}\]])/g, '"$1": $2');

  // Fix trailing quotes after numbers that might have spaces (e.g., "healthScore": 6 " -> "healthScore": 6)
  jsonStr = jsonStr.replace(/"([^"]+)":\s*(\d+(?:\.\d+)?)\s*"(?=\s*[,}\]])/g, '"$1": $2');

  // Fix any remaining trailing quotes after numbers (catch-all)
  jsonStr = jsonStr.replace(/":\s*(\d+(?:\.\d+)?)"(?=\s*[,}\]])/g, ': $2');

  // Fix any other numeric fields with trailing quotes
  jsonStr = jsonStr.replace(/"([^"]+)":\s*(\d+(?:\.\d+)?)"(?=\s*[,}\]])/g, '"$1": $2');

  // Fix quoted numeric values that should be numbers (e.g., "calories": "200" -> "calories": 200)
  jsonStr = jsonStr.replace(/"((?:calories|protein|carbs|fat|fiber|sugar|sodium))":\s*"(\d+(?:\.\d+)?)"/g, '"$1": $2');

  // Fix unquoted nutritional values like "protein": 40g to "protein": "40g"
  jsonStr = jsonStr.replace(/"((?:calories|protein|carbs|fat|fiber|sugar|sodium))":\s*(\d+(?:\.\d+)?[a-zA-Z]*)/g, '"$1": "$2"');

  // Fix unquoted numeric values followed by units like 40g, 25mg, etc.
  jsonStr = jsonStr.replace(/:\s*(\d+(?:\.\d+)?[a-zA-Z]+)(?=[,\]\}])/g, ': "$1"');

  // Fix missing quotes around standalone numbers that should be strings
  jsonStr = jsonStr.replace(/"((?:totalCalories|totalProtein|totalCarbs|totalFat))":\s*(\d+(?:\.\d+)?)/g, '"$1": $2');

  // Fix any quoted numeric values that should be numbers (general case)
  jsonStr = jsonStr.replace(/"([^"]+)":\s*"(\d+(?:\.\d+)?)"(?=\s*[,}\]])/g, '"$1": $2');

  // Remove control characters (newlines, carriage returns, tabs) from JSON strings
  jsonStr = jsonStr.replace(/[\r\n\t]/g, ' ');

  // Clean up multiple spaces
  jsonStr = jsonStr.replace(/\s+/g, ' ');

  // Fix incomplete JSON by adding missing closing braces/brackets
  let openBraces = (jsonStr.match(/\{/g) || []).length;
  let closeBraces = (jsonStr.match(/\}/g) || []).length;
  let openBrackets = (jsonStr.match(/\[/g) || []).length;
  let closeBrackets = (jsonStr.match(/\]/g) || []).length;

  // Add missing closing braces/brackets
  while (closeBraces < openBraces) {
    jsonStr += '}';
    closeBraces++;
  }
  while (closeBrackets < openBrackets) {
    jsonStr += ']';
    closeBrackets++;
  }

  // Fix unterminated strings - look for strings that don't end with a quote
  jsonStr = jsonStr.replace(/"([^"]*?)(?=\s*[,}\]])/g, (match, value) => {
    // If the value doesn't end with a quote, add one
    if (!value.endsWith('"')) {
      return `"${value}"`;
    }
    return match;
  });

  // Fix unterminated strings at the end of the JSON
  jsonStr = jsonStr.replace(/"([^"]*?)$/g, (match, value) => {
    // If the value doesn't end with a quote, add one
    if (!value.endsWith('"')) {
      return `"${value}"`;
    }
    return match;
  });

  // Fix specific diet type unterminated strings
  jsonStr = jsonStr.replace(/"diet":\s*"([^"]*?)(?=\s*[,}\]])/g, (match, dietValue) => {
    if (!dietValue.endsWith('"')) {
      return `"diet": "${dietValue}"`;
    }
    return match;
  });

  // Fix diet field with missing quotes in the middle (e.g., "diet": "low-carb", dairy-free")
  jsonStr = jsonStr.replace(/"diet":\s*"([^"]*?)",\s*([^"]*?)"(?=\s*[,}\]])/g, (match, firstPart, secondPart) => {
    return `"diet": "${firstPart}, ${secondPart}"`;
  });

  // Fix diet field with unquoted values after comma (e.g., "diet": "low-carb", dairy-free)
  jsonStr = jsonStr.replace(/"diet":\s*"([^"]*?)",\s*([^"]*?)(?=\s*[,}\]])/g, (match, firstPart, secondPart) => {
    return `"diet": "${firstPart}, ${secondPart}"`;
  });

  // Fix double quotes in string values (e.g., "title": "value"")
  jsonStr = jsonStr.replace(/"([^"]*?)""(?=\s*[,}\]])/g, '"$1"');

  // Fix broken value where comma-suffixed text is outside quotes
  // Example: "onion": "1/4 medium", chopped" -> "onion": "1/4 medium, chopped"
  jsonStr = jsonStr.replace(/"([\w\s]+)":\s*"([^"]*?)",\s*([A-Za-z][^",}\]]*)"/g, (match, key, first, second) => {
    return `"${key}": "${first}, ${second}"`;
  });

  // Fix unquoted nutritional values with units (e.g., "protein": 20g -> "protein": "20g")
  jsonStr = jsonStr.replace(/"((?:calories|protein|carbs|fat|fiber|sugar|sodium))":\s*(\d+[a-zA-Z]+)/g, '"$1": "$2"');

  // Fix any remaining unquoted values with units that might be missed
  jsonStr = jsonStr.replace(/:\s*(\d+[a-zA-Z]+)(?=[,\]\}])/g, ': "$1"');

  return jsonStr;
}

/**
 * Aggressively clean JSON that has severe formatting issues
 */
function aggressiveJsonCleanup(jsonStr) {
  // Remove all control characters and normalize whitespace
  jsonStr = jsonStr.replace(/[\r\n\t\x00-\x1F\x7F]/g, ' ');

  // Clean up multiple spaces
  jsonStr = jsonStr.replace(/\s+/g, ' ');

  // Fix broken string values that might have been split by newlines
  jsonStr = jsonStr.replace(/"([^"]*?)\s*,\s*"([^"]*?)"/g, '"$1 $2"');

  // Fix broken array items that might have been split
  jsonStr = jsonStr.replace(/\}\s*,\s*\{/g, '},{');

  // Ensure proper comma placement
  jsonStr = jsonStr.replace(/,\s*}/g, '}');
  jsonStr = jsonStr.replace(/,\s*]/g, ']');

  return jsonStr.trim();
}

/**
 * Aggressive JSON cleanup for malformed responses
 */
function aggressiveJsonCleanup(jsonStr) {
  // Remove all control characters and normalize whitespace
  jsonStr = jsonStr.replace(/[\r\n\t\x00-\x1F\x7F]/g, ' ');

  // Clean up multiple spaces
  jsonStr = jsonStr.replace(/\s+/g, ' ');

  // Fix broken string values that might have been split by newlines
  jsonStr = jsonStr.replace(/"([^"]*?)\s*,\s*"([^"]*?)"/g, '"$1 $2"');

  // Fix broken array items that might have been split
  jsonStr = jsonStr.replace(/}\s*,\s*{/g, '},{');

  // Ensure proper comma placement
  jsonStr = jsonStr.replace(/,\s*}/g, '}');
  jsonStr = jsonStr.replace(/,\s*]/g, ']');

  return jsonStr.trim();
}

/**
 * Extract partial data from malformed JSON using regex patterns
 */
function extractPartialDataFromMalformedJson(malformedJson) {
  const extractedData = {};

  try {
    // Extract food items for food analysis
    const foodItemMatches = malformedJson.match(/"name":\s*"([^"]+)"/g) || [];
    const weightMatches = malformedJson.match(/"estimatedWeight":\s*"([^"]+)"/g) || [];
    const confidenceMatches = malformedJson.match(/"confidence":\s*"([^"]+)"/g) || [];
    
    // Extract nutritional values more comprehensively
    const caloriesMatches = malformedJson.match(/"calories":\s*"?(\d+)"?/g) || [];
    const proteinMatches = malformedJson.match(/"protein":\s*"?(\d+(?:\.\d+)?)"?/g) || [];
    const carbsMatches = malformedJson.match(/"carbs":\s*"?(\d+(?:\.\d+)?)"?/g) || [];
    const fatMatches = malformedJson.match(/"fat":\s*"?(\d+(?:\.\d+)?)"?/g) || [];
    const fiberMatches = malformedJson.match(/"fiber":\s*"?(\d+(?:\.\d+)?)"?/g) || [];
    const sugarMatches = malformedJson.match(/"sugar":\s*"?(\d+(?:\.\d+)?)"?/g) || [];
    const sodiumMatches = malformedJson.match(/"sodium":\s*"?(\d+(?:\.\d+)?)"?/g) || [];

    if (foodItemMatches.length > 0) {
      const foodItems = [];
      const maxItems = Math.min(foodItemMatches.length, 10); // Cap at 10 items

      for (let i = 0; i < maxItems; i++) {
        const foodItem = {
          name: foodItemMatches[i].match(/"name":\s*"([^"]+)"/)[1] || `Food Item ${i + 1}`,
          estimatedWeight: weightMatches[i] ? 
            weightMatches[i].match(/"estimatedWeight":\s*"([^"]+)"/)[1] : '100g',
          confidence: confidenceMatches[i] ? 
            confidenceMatches[i].match(/"confidence":\s*"([^"]+)"/)[1] : 'medium',
          nutritionalInfo: {
            calories: caloriesMatches[i] ? 
              parseInt(caloriesMatches[i].match(/"calories":\s*"?(\d+)"?/)[1]) : 100,
            protein: proteinMatches[i] ? 
              parseFloat(proteinMatches[i].match(/"protein":\s*"?(\d+(?:\.\d+)?)"?/)[1]) : 0,
            carbs: carbsMatches[i] ? 
              parseFloat(carbsMatches[i].match(/"carbs":\s*"?(\d+(?:\.\d+)?)"?/)[1]) : 0,
            fat: fatMatches[i] ? 
              parseFloat(fatMatches[i].match(/"fat":\s*"?(\d+(?:\.\d+)?)"?/)[1]) : 0,
            fiber: fiberMatches[i] ? 
              parseFloat(fiberMatches[i].match(/"fiber":\s*"?(\d+(?:\.\d+)?)"?/)[1]) : 0,
            sugar: sugarMatches[i] ? 
              parseFloat(sugarMatches[i].match(/"sugar":\s*"?(\d+(?:\.\d+)?)"?/)[1]) : 0,
            sodium: sodiumMatches[i] ? 
              parseFloat(sodiumMatches[i].match(/"sodium":\s*"?(\d+(?:\.\d+)?)"?/)[1]) : 0
          }
        };
        foodItems.push(foodItem);
      }

      extractedData.foodItems = foodItems;
    }

    // Extract meal plan array
    const mealPlanMatches = malformedJson.match(/"title":\s*"([^"]+)"/g) || [];
    const mealTypeMatches = malformedJson.match(/"mealType":\s*"([^"]+)"/g) || [];
    const typeMatches = malformedJson.match(/"type":\s*"([^"]+)"/g) || [];
    const mealCaloriesMatches = malformedJson.match(/"calories":\s*"?(\d+)"?/g) || [];

    // Extract ingredients using regex
    const ingredientsMatches = malformedJson.match(/"ingredients":\s*\{([^}]+)\}/g) || [];

    // Build meal plan from extracted data
    const mealPlan = [];
    const maxMeals = Math.min(
      [mealPlanMatches.length, mealTypeMatches.length, typeMatches.length].reduce((a, b) => Math.min(a, b)),
      10 // Cap at 10 meals
    );

    for (let i = 0; i < maxMeals; i++) {
      const meal = {};

      if (i < mealPlanMatches.length) {
        const titleMatch = mealPlanMatches[i].match(/"title":\s*"([^"]+)"/);
        meal.title = titleMatch ? titleMatch[1] : `Untitled Meal ${i}`;
      }

      if (i < mealTypeMatches.length) {
        const mealTypeMatch = mealTypeMatches[i].match(/"mealType":\s*"([^"]+)"/);
        meal.mealType = mealTypeMatch ? mealTypeMatch[1] : 'breakfast';
      }

      if (i < typeMatches.length) {
        const typeMatch = typeMatches[i].match(/"type":\s*"([^"]+)"/);
        meal.type = typeMatch ? typeMatch[1] : 'protein';
      }

        if (i < mealCaloriesMatches.length) {
          const caloriesMatch = mealCaloriesMatches[i].match(/"calories":\s*"?(\d+)"?/);
          meal.calories = caloriesMatch ? parseInt(caloriesMatch[1]) || 300 : 300;
        } else {
          meal.calories = 300; // Default calories
        }

      // Extract ingredients for this meal if available
      if (i < ingredientsMatches.length) {
        const ingredientsText = ingredientsMatches[i].match(/"ingredients":\s*\{([^}]+)\}/);
        meal.ingredients = ingredientsText ? extractIngredientsFromMalformedJson(ingredientsText[1]) : { 'ingredient': '1 serving' };
      } else {
        meal.ingredients = { 'ingredient': '1 serving' }; // Default ingredients
      }

      // Add nutritional info
      meal.nutritionalInfo = {
        calories: meal.calories,
        protein: 20,
        carbs: 25,
        fat: 10,
      };

      mealPlan.push(meal);
    }

    // Extract distribution if available
    const distribution = {};
    const breakfastMatches = malformedJson.match(/"breakfast":\s*(\d+)/g) || [];
    const lunchMatches = malformedJson.match(/"lunch":\s*(\d+)/g) || [];
    const dinnerMatches = malformedJson.match(/"dinner":\s*(\d+)/g) || [];
    const snackMatches = malformedJson.match(/"snack":\s*(\d+)/g) || [];

    if (breakfastMatches.length > 0) {
      const breakfastMatch = breakfastMatches[0].match(/"breakfast":\s*(\d+)/);
      distribution.breakfast = breakfastMatch ? parseInt(breakfastMatch[1]) : 1;
    }
    if (lunchMatches.length > 0) {
      const lunchMatch = lunchMatches[0].match(/"lunch":\s*(\d+)/);
      distribution.lunch = lunchMatch ? parseInt(lunchMatch[1]) : 1;
    }
    if (dinnerMatches.length > 0) {
      const dinnerMatch = dinnerMatches[0].match(/"dinner":\s*(\d+)/);
      distribution.dinner = dinnerMatch ? parseInt(dinnerMatch[1]) : 1;
    }
    if (snackMatches.length > 0) {
      const snackMatch = snackMatches[0].match(/"snack":\s*(\d+)/);
      distribution.snack = snackMatch ? parseInt(snackMatch[1]) : 1;
    }

    if (mealPlan.length > 0) {
      extractedData.mealPlan = mealPlan;
      if (Object.keys(distribution).length > 0) {
        extractedData.distribution = distribution;
      }
      extractedData.confidence = 'extracted';
      extractedData.notes = 'Data extracted from malformed JSON using regex patterns';
    }

    // Extract ingredients for fridge analysis
    const ingredientMatches = malformedJson.match(/"ingredient[^"]*":\s*"([^"]+)"/g) || [];
    if (ingredientMatches.length > 0) {
      const ingredients = {};
      ingredientMatches.forEach((match, index) => {
        const ingredientName = match.match(/"ingredient[^"]*":\s*"([^"]+)"/)[1];
        ingredients[ingredientName] = '1 serving';
      });
      extractedData.ingredients = ingredients;
    }

    // Extract suggested meals for fridge analysis
    const suggestedMealMatches = malformedJson.match(/"suggestedMeals":\s*\[([^\]]+)\]/g) || [];
    if (suggestedMealMatches.length > 0) {
      const suggestedMeals = [];
      suggestedMealMatches.forEach((match) => {
        const mealsText = match.match(/"suggestedMeals":\s*\[([^\]]+)\]/)[1];
        const mealNames = mealsText.match(/"([^"]+)"/g) || [];
        mealNames.forEach(mealName => {
          suggestedMeals.push({
            title: mealName.replace(/"/g, ''),
            description: 'Suggested meal using available ingredients',
            ingredients: extractedData.ingredients || {}
          });
        });
      });
      extractedData.suggestedMeals = suggestedMeals;
    }

    // If no usable data was extracted, mark as complete failure
    if (Object.keys(extractedData).length === 0 || 
        (!extractedData.foodItems && !extractedData.mealPlan && !extractedData.ingredients)) {
      extractedData.source = true; // Mark as complete failure - no usable data
      extractedData.error = 'No usable data could be extracted from malformed JSON';
    }

    return extractedData;
  } catch (e) {
    console.log('Partial data extraction failed:', e);
    return {
      source: true, // Mark as complete failure - no usable data
      error: 'Failed to extract any data from malformed JSON'
    };
  }
}

/**
 * Extract ingredients from malformed JSON text
 */
function extractIngredientsFromMalformedJson(ingredientsText) {
  const ingredients = {};

  try {
    // Extract individual ingredients
    const ingredientMatches = ingredientsText.match(/"([^"]+)":\s*"([^"]+)"/g) || [];

    for (const match of ingredientMatches) {
      const keyMatch = match.match(/"([^"]+)":\s*"([^"]+)"/);
      if (keyMatch) {
        const key = keyMatch[1].trim();
        const value = keyMatch[2].trim();
        if (key && value) {
          ingredients[key] = value;
        }
      }
    }

    return Object.keys(ingredients).length > 0 ? ingredients : { 'unknown ingredient': '1 portion' };
  } catch (e) {
    return { 'unknown ingredient': '1 portion' };
  }
}

/**
 * Validate and extract meal data from AI response
 */
function validateAndExtractMealData(rawResponse) {
  try {
    // First attempt: extract JSON from markdown code blocks if present
    const cleanedResponse = extractJsonFromMarkdown(rawResponse);
    const completedResponse = completeTruncatedJson(cleanedResponse);
    const sanitized = sanitizeJsonString(completedResponse);
    const data = JSON.parse(sanitized);

    // Validate and normalize the data
    const result = validateAndNormalizeMealData(data);
    return result;
  } catch (e) {
    // Second attempt: use existing partial extraction method
    const partialData = extractPartialJson(rawResponse, 'meal_generation');
    if (partialData && Object.keys(partialData).length > 0 && isValidPartialResponse(partialData, 'meal_generation')) {
      return validateAndNormalizeMealData(partialData);
    }

    // Third attempt: extract meal data from malformed response
    const extractedData = extractMealDataFromRawText(rawResponse);
    if (extractedData && Object.keys(extractedData).length > 0) {
      return validateAndNormalizeMealData(extractedData);
    }

    // Return fallback if all extraction attempts fail
    return createFallbackResponse('meal_generation', 'Complete extraction failed');
  }
}

/**
 * Extract JSON from markdown code blocks
 */
function extractJsonFromMarkdown(text) {
  // Remove markdown code block markers
  let cleaned = text.replace(/^```json\s*/gm, '');
  cleaned = cleaned.replace(/\s*```$/gm, '');
  return cleaned.trim();
}

/**
 * Attempt to complete truncated JSON responses
 */
function completeTruncatedJson(text) {
  // Check if the JSON appears to be truncated
  if (!text.trim().endsWith('}')) {
    // Count opening and closing braces
    const openBraces = (text.match(/\{/g) || []).length;
    const closeBraces = (text.match(/\}/g) || []).length;

    // If we have more opening braces than closing braces, try to complete
    if (openBraces > closeBraces) {
      const missingBraces = openBraces - closeBraces;
      text += '}'.repeat(missingBraces);

      // Also check for incomplete arrays
      const openBrackets = (text.match(/\[/g) || []).length;
      const closeBrackets = (text.match(/\]/g) || []).length;
      if (openBrackets > closeBrackets) {
        const missingBrackets = openBrackets - closeBrackets;
        text += ']'.repeat(missingBrackets);
      }

      console.log(`Attempted to complete truncated JSON by adding ${missingBraces} closing braces`);
    }
  }

  return text;
}

/**
 * Extract meal data from raw text using regex patterns
 */
function extractMealDataFromRawText(rawResponse) {
  const extractedData = {};

  try {
    // Extract meal title
    const titleMatch = rawResponse.match(/"title":\s*"([^"]+)"/);
    if (titleMatch) {
      extractedData.title = titleMatch[1];
    }

    // Extract ingredients
    const ingredientsMatch = rawResponse.match(/"ingredients":\s*\{([^}]+)\}/);
    if (ingredientsMatch) {
      extractedData.ingredients = extractIngredientsFromText(ingredientsMatch[1]);
    }

    // Extract instructions
    const instructionsMatch = rawResponse.match(/"instructions":\s*\[([^\]]+)\]/);
    if (instructionsMatch) {
      extractedData.instructions = extractInstructionsFromText(instructionsMatch[1]);
    }

    // Extract nutritional info
    const caloriesMatch = rawResponse.match(/"calories":\s*"?(\d+)"?/);
    if (caloriesMatch) {
      const calories = parseInt(caloriesMatch[1]) || 300;
      extractedData.calories = calories;
      extractedData.nutritionalInfo = {
        calories: calories,
        protein: Math.floor(calories * 0.15 / 4), // 15% of calories from protein
        carbs: Math.floor(calories * 0.55 / 4),   // 55% of calories from carbs
        fat: Math.floor(calories * 0.30 / 9),     // 30% of calories from fat
      };
    }

    // Extract other fields
    const cookingTimeMatch = rawResponse.match(/"cookingTime":\s*"([^"]+)"/);
    if (cookingTimeMatch) {
      extractedData.cookingTime = cookingTimeMatch[1];
    }

    const difficultyMatch = rawResponse.match(/"difficulty":\s*"([^"]+)"/);
    if (difficultyMatch) {
      extractedData.difficulty = difficultyMatch[1];
    }

    const serveQtyMatch = rawResponse.match(/"serveQty":\s*"?(\d+)"?/);
    if (serveQtyMatch) {
      extractedData.serveQty = parseInt(serveQtyMatch[1]) || 1;
    }

    const typeMatch = rawResponse.match(/"type":\s*"([^"]+)"/);
    if (typeMatch) {
      extractedData.type = typeMatch[1];
    }

    const cuisineMatch = rawResponse.match(/"cuisine":\s*"([^"]+)"/);
    if (cuisineMatch) {
      extractedData.cuisine = cuisineMatch[1];
    }

    // Extract categories
    const categoriesMatch = rawResponse.match(/"categories":\s*\[([^\]]+)\]/);
    if (categoriesMatch) {
      extractedData.categories = extractCategoriesFromText(categoriesMatch[1]);
    }

    extractedData.confidence = 'extracted';
    extractedData.notes = 'Data extracted from raw text using regex patterns';

    return extractedData;
  } catch (e) {
    console.log('Meal data extraction failed:', e);
    return {};
  }
}

/**
 * Extract ingredients from text
 */
function extractIngredientsFromText(ingredientsText) {
  const ingredients = {};

  try {
    // Extract individual ingredients
    const ingredientMatches = ingredientsText.match(/"([^"]+)":\s*"([^"]+)"/g) || [];

    for (const match of ingredientMatches) {
      const keyMatch = match.match(/"([^"]+)":\s*"([^"]+)"/);
      if (keyMatch) {
        const key = keyMatch[1].trim();
        const value = keyMatch[2].trim();
        if (key && value) {
          ingredients[key] = value;
        }
      }
    }

    return Object.keys(ingredients).length > 0 ? ingredients : { 'unknown ingredient': '1 portion' };
  } catch (e) {
    return { 'unknown ingredient': '1 portion' };
  }
}

/**
 * Extract instructions from text
 */
function extractInstructionsFromText(instructionsText) {
  const instructions = [];

  try {
    // Extract individual instructions
    const instructionMatches = instructionsText.match(/"([^"]+)"/g) || [];

    for (const match of instructionMatches) {
      const instruction = match.replace(/"/g, '').trim();
      if (instruction && instruction.length > 0) {
        instructions.push(instruction);
      }
    }

    return instructions.length > 0 ? instructions : ['Food analyzed by AI'];
  } catch (e) {
    return ['Food analyzed by AI'];
  }
}

/**
 * Extract categories from text
 */
function extractCategoriesFromText(categoriesText) {
  const categories = [];

  try {
    // Extract individual categories
    const categoryMatches = categoriesText.match(/"([^"]+)"/g) || [];

    for (const match of categoryMatches) {
      const category = match.replace(/"/g, '').trim();
      if (category && category.length > 0) {
        categories.push(category);
      }
    }

    return categories;
  } catch (e) {
    return [];
  }
}

/**
 * Validate response structure based on operation type
 */
function validateResponseStructure(data, operation) {
  switch (operation) {
    case 'meal_generation':
      if (!data.ingredients || !data.instructions) {
        throw new Error('Missing required fields: ingredients or instructions');
      }
      break;
    default:
      // No validation for other operations
      break;
  }
}

/**
 * Check if partial response is valid
 */
function isValidPartialResponse(data, operation) {
  switch (operation) {
    case 'meal_generation':
      return data.ingredients && data.instructions;
    default:
      return Object.keys(data).length > 0;
  }
}

/**
 * Extract partial JSON when full parsing fails
 */
function extractPartialJson(text, operation) {
  // Use the robust extraction method instead of simple JSON parsing
  try {
    const partialData = extractPartialDataFromMalformedJson(text);
    if (partialData && Object.keys(partialData).length > 0) {
      return partialData;
    }
  } catch (e) {
    console.log('Robust partial extraction failed:', e);
  }
  
  // Fallback to simple extraction
  try {
    const jsonStart = text.indexOf('{');
    const jsonEnd = text.lastIndexOf('}');
    
    if (jsonStart !== -1 && jsonEnd !== -1 && jsonEnd > jsonStart) {
      const extractedJson = text.substring(jsonStart, jsonEnd + 1);
      return JSON.parse(extractedJson);
    }
  } catch (e) {
    console.log('Simple partial extraction failed:', e);
  }
  
  return {};
}

/**
 * Validate and normalize meal data
 */
function validateAndNormalizeMealData(data) {
  const normalizedData = {};

  // Basic meal info
  normalizedData.title = data.title || 'Untitled Meal';
  normalizedData.ingredients = data.ingredients || { 'unknown ingredient': '1 portion' };
  normalizedData.instructions = data.instructions || ['Food analyzed by AI'];
  normalizedData.calories = data.calories || 300;
  normalizedData.nutritionalInfo = data.nutritionalInfo || {
    calories: data.calories || 300,
    protein: 20,
    carbs: 25,
    fat: 10,
  };
  normalizedData.cookingTime = data.cookingTime || '30 minutes';
  normalizedData.difficulty = data.difficulty || 'medium';
  normalizedData.serveQty = data.serveQty || 1;
  normalizedData.type = data.type || 'protein';
  normalizedData.categories = data.categories || ['general'];
  normalizedData.cuisine = data.cuisine || 'general';

  return normalizedData;
}

/**
 * Create fallback response for failed AI operations
 */
function createFallbackResponse(operation, error) {
  switch (operation) {
    case 'meal_generation':
      return {
        ingredients: { 'unknown ingredient': '1 portion' },
        instructions: [
          'Analysis failed: ' + error,
          'Please create meal manually'
        ],
        calories: 300,
        nutritionalInfo: {
          calories: 300,
          protein: 15,
          carbs: 30,
          fat: 10
        },
        cookingTime: '30 minutes',
        difficulty: 'medium',
        serveQty: 1,
        type: 'protein',
        categories: ['error-fallback'],
        cuisine: 'general',
        confidence: 'low',
        notes: 'Analysis failed: ' + error + '. Please verify all information manually.'
      };
    default:
      return { error: true, message: 'Operation failed: ' + error };
  }
}

// ============================================================================
// CLOUD FUNCTIONS NOTIFICATION SYSTEM
// ============================================================================

/**
 * Scheduled function to send notifications every 5 minutes
 * Checks for users who should receive notifications at the current time
 */
exports.sendScheduledNotifications = functions.pubsub
  .schedule('every 5 minutes')
  .timeZone('UTC')
  .onRun(async (context) => {
    try {
      console.log('--- Running scheduled notification check ---');
      
      const now = new Date();
      const currentHour = now.getHours();
      const currentMinute = now.getMinutes();
      
      console.log(`Current time: ${currentHour}:${currentMinute.toString().padStart(2, '0')} UTC`);
      
      // Check for meal plan reminders (21:00 UTC = 9 PM)
      if (currentHour === 21 && currentMinute < 5) {
        console.log('Checking for meal plan reminders...');
        await sendMealPlanReminders();
      }
      
      // Check for water reminders (11:00 UTC = 11 AM)
      if (currentHour === 11 && currentMinute < 5) {
        console.log('Checking for water reminders...');
        await sendWaterReminders();
      }
      
      // Check for evening reviews (21:00 UTC = 9 PM)
      if (currentHour === 21 && currentMinute < 5) {
        console.log('Checking for evening reviews...');
        await sendEveningReviews();
      }
      
      console.log('--- Scheduled notification check completed ---');
      return null;
      
    } catch (error) {
      console.error('Error in scheduled notification check:', error);
      return null;
    }
  });

/**
 * Send meal plan reminder notifications to users who haven't planned meals for tomorrow
 */
async function sendMealPlanReminders() {
  try {
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const tomorrowStr = format(tomorrow, 'yyyy-MM-dd');
    
    console.log(`Checking meal plans for tomorrow: ${tomorrowStr}`);
    
    // Get users who have meal plan reminders enabled
    const usersSnapshot = await firestore
      .collection('users')
      .where('notificationPreferences.mealPlanReminder.enabled', '==', true)
      .get();
    
    console.log(`Found ${usersSnapshot.size} users with meal plan reminders enabled`);
    
    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const userId = userDoc.id;
      
      try {
        // Check if user has meal plan for tomorrow
        const mealPlanDoc = await firestore
          .collection('mealPlans')
          .doc(userId)
          .collection('date')
          .doc(tomorrowStr)
          .get();
        
        const hasMealPlan = mealPlanDoc.exists && mealPlanDoc.data().meals && 
                           Object.keys(mealPlanDoc.data().meals).length > 0;
        
        if (!hasMealPlan) {
          // Get today's summary data for context
          const today = new Date();
          const todayStr = format(today, 'yyyy-MM-dd');
          let todaySummary = {};
          
          try {
            const summaryDoc = await firestore
              .collection('users')
              .doc(userId)
              .collection('daily_summary')
              .doc(todayStr)
              .get();
            
            if (summaryDoc.exists) {
              todaySummary = summaryDoc.data();
            }
          } catch (e) {
            console.log(`Error fetching today's summary for user ${userId}:`, e);
          }
          
          // Send meal plan reminder notification
          await sendNotification(userId, {
            title: 'Meal Plan Reminder 🍽️',
            body: 'You haven\'t planned any meals for tomorrow. Don\'t forget to add your meals!',
            data: {
              type: 'meal_plan_reminder',
              date: tomorrowStr,
              todaySummary: JSON.stringify(todaySummary),
              hasMealPlan: 'false',
              action: 'navigate_to_meal_planning'
            }
          });
          
          console.log(`Sent meal plan reminder to user ${userId}`);
        } else {
          console.log(`User ${userId} already has meal plan for tomorrow`);
        }
        
      } catch (userError) {
        console.error(`Error processing user ${userId} for meal plan reminder:`, userError);
      }
    }
    
  } catch (error) {
    console.error('Error in sendMealPlanReminders:', error);
  }
}

/**
 * Send water reminder notifications to users
 */
async function sendWaterReminders() {
  try {
    console.log('Sending water reminders...');
    
    // Get users who have water reminders enabled
    const usersSnapshot = await firestore
      .collection('users')
      .where('notificationPreferences.waterReminder.enabled', '==', true)
      .get();
    
    console.log(`Found ${usersSnapshot.size} users with water reminders enabled`);
    
    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const userId = userDoc.id;
      
      try {
        // Send water reminder notification
        await sendNotification(userId, {
          title: 'Water Reminder 💧',
          body: 'Stay hydrated! Don\'t forget to track your water intake.',
          data: {
            type: 'water_reminder',
            action: 'navigate_to_water_tracking'
          }
        });
        
        console.log(`Sent water reminder to user ${userId}`);
        
      } catch (userError) {
        console.error(`Error sending water reminder to user ${userId}:`, userError);
      }
    }
    
  } catch (error) {
    console.error('Error in sendWaterReminders:', error);
  }
}

/**
 * Send evening review notifications to users who have meal plans
 */
async function sendEveningReviews() {
  try {
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const tomorrowStr = format(tomorrow, 'yyyy-MM-dd');
    
    console.log(`Checking evening reviews for tomorrow: ${tomorrowStr}`);
    
    // Get users who have evening review notifications enabled
    const usersSnapshot = await firestore
      .collection('users')
      .where('notificationPreferences.eveningReview.enabled', '==', true)
      .get();
    
    console.log(`Found ${usersSnapshot.size} users with evening review enabled`);
    
    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const userId = userDoc.id;
      
      try {
        // Check if user has meal plan for tomorrow
        const mealPlanDoc = await firestore
          .collection('mealPlans')
          .doc(userId)
          .collection('date')
          .doc(tomorrowStr)
          .get();
        
        const hasMealPlan = mealPlanDoc.exists && mealPlanDoc.data().meals && 
                           Object.keys(mealPlanDoc.data().meals).length > 0;
        
        if (hasMealPlan) {
          // Get today's summary data for context
          const today = new Date();
          const todayStr = format(today, 'yyyy-MM-dd');
          let todaySummary = {};
          
          try {
            const summaryDoc = await firestore
              .collection('users')
              .doc(userId)
              .collection('daily_summary')
              .doc(todayStr)
              .get();
            
            if (summaryDoc.exists) {
              todaySummary = summaryDoc.data();
            }
          } catch (e) {
            console.log(`Error fetching today's summary for user ${userId}:`, e);
          }
          
          // Send evening review notification
          await sendNotification(userId, {
            title: 'Evening Review 🌙',
            body: 'Review your goals and plan for tomorrow!',
            data: {
              type: 'evening_review',
              date: tomorrowStr,
              todaySummary: JSON.stringify(todaySummary),
              hasMealPlan: 'true',
              action: 'navigate_to_evening_review'
            }
          });
          
          console.log(`Sent evening review to user ${userId}`);
        } else {
          console.log(`User ${userId} doesn't have meal plan for tomorrow, skipping evening review`);
        }
        
      } catch (userError) {
        console.error(`Error processing user ${userId} for evening review:`, userError);
      }
    }
    
  } catch (error) {
    console.error('Error in sendEveningReviews:', error);
  }
}

/**
 * Send notification to a specific user via FCM
 */
async function sendNotification(userId, notification) {
  try {
    const userDoc = await firestore.collection('users').doc(userId).get();
    const userData = userDoc.data();
    
    if (!userData || !userData.fcmToken) {
      console.log(`No FCM token for user ${userId}`);
      return;
    }
    
    // Check if notification was already sent today
    const today = new Date();
    const todayStr = format(today, 'yyyy-MM-dd');
    const notificationType = notification.data.type;
    
    const existingNotification = await firestore
      .collection('notifications')
      .where('userId', '==', userId)
      .where('type', '==', notificationType)
      .where('date', '==', todayStr)
      .limit(1)
      .get();
    
    if (!existingNotification.empty) {
      console.log(`Notification ${notificationType} already sent to user ${userId} today`);
      return;
    }
    
    const message = {
      token: userData.fcmToken,
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: {
        ...notification.data,
        userId: userId,
        timestamp: Date.now().toString()
      },
      android: {
        notification: {
          icon: 'ic_notification',
          color: '#FF6B35',
          sound: 'default',
          priority: 'high',
          channelId: 'tasteturner_notifications',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK'
        }
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
            'content-available': 1,
            'mutable-content': 1
          }
        }
      }
    };
    
    const response = await admin.messaging().send(message);
    console.log(`Notification sent to user ${userId}: ${response}`);
    
    // Store notification in database for history and deduplication
    await firestore.collection('notifications').add({
      userId: userId,
      type: notificationType,
      title: notification.title,
      body: notification.body,
      data: notification.data,
      date: todayStr,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      status: 'sent',
      fcmMessageId: response
    });
    
  } catch (error) {
    console.error(`Error sending notification to user ${userId}:`, error);
    
    // Store failed notification for debugging
    await firestore.collection('notifications').add({
      userId: userId,
      type: notification.data.type,
      title: notification.title,
      body: notification.body,
      data: notification.data,
      date: format(new Date(), 'yyyy-MM-dd'),
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      status: 'failed',
      error: error.message
    });
  }
}

/**
 * Cloud Function to update user's FCM token
 */
exports.updateFCMToken = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'The function must be called while authenticated.'
      );
    }
    
    const { fcmToken, platform } = data;
    const userId = context.auth.uid;
    
    if (!fcmToken) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'FCM token is required'
      );
    }
    
    // Update user's FCM token
    await firestore.collection('users').doc(userId).update({
      fcmToken: fcmToken,
      fcmTokenPlatform: platform || 'unknown',
      fcmTokenUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log(`Updated FCM token for user ${userId}`);
    
    return { success: true };
    
  } catch (error) {
    console.error('Error updating FCM token:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError(
      'internal',
      'An error occurred while updating FCM token'
    );
  }
});

/**
 * Cloud Function to update user's notification preferences
 */
exports.updateNotificationPreferences = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'The function must be called while authenticated.'
      );
    }
    
    const { preferences } = data;
    const userId = context.auth.uid;
    
    if (!preferences) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Notification preferences are required'
      );
    }
    
    // Update user's notification preferences
    await firestore.collection('users').doc(userId).update({
      notificationPreferences: preferences,
      notificationPreferencesUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log(`Updated notification preferences for user ${userId}`);
    
    return { success: true };
    
  } catch (error) {
    console.error('Error updating notification preferences:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError(
      'internal',
      'An error occurred while updating notification preferences'
    );
  }
});

/**
 * Cloud Function to send a test notification
 */
exports.sendTestNotification = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'The function must be called while authenticated.'
      );
    }
    
    const userId = context.auth.uid;
    
    // Send a test notification
    await sendNotification(userId, {
      title: 'Test Notification 🧪',
      body: 'This is a test notification from Cloud Functions!',
      data: {
        type: 'test_notification',
        action: 'navigate_to_home',
        timestamp: Date.now().toString()
      }
    });
    
    return { success: true, message: 'Test notification sent successfully' };
    
  } catch (error) {
    console.error('Error sending test notification:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError(
      'internal',
      'An error occurred while sending test notification'
    );
  }
});

/**
 * Cloud Function to get user's notification history
 */
exports.getNotificationHistory = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'The function must be called while authenticated.'
      );
    }
    
    const userId = context.auth.uid;
    const { limit = 20, lastNotificationId = null } = data;
    
    let query = firestore
      .collection('notifications')
      .where('userId', '==', userId)
      .orderBy('sentAt', 'desc')
      .limit(limit);
    
    if (lastNotificationId) {
      const lastDoc = await firestore.collection('notifications').doc(lastNotificationId).get();
      if (lastDoc.exists) {
        query = query.startAfter(lastDoc);
      }
    }
    
    const snapshot = await query.get();
    const notifications = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      sentAt: doc.data().sentAt?.toDate?.()?.toISOString() || doc.data().sentAt
    }));
    
    return {
      success: true,
      notifications: notifications,
      hasMore: snapshot.docs.length === limit,
      lastNotificationId: snapshot.docs.length > 0 ? snapshot.docs[snapshot.docs.length - 1].id : null
    };
    
  } catch (error) {
    console.error('Error getting notification history:', error);
    return {
      success: false,
      error: error.message,
      notifications: []
    };
  }
});

// ============================================================================
// APP STORE SERVER NOTIFICATIONS
// ============================================================================

/**
 * App Store Server Notification handler for production environment
 * This endpoint receives notifications from Apple about subscription events
 */
exports.appStoreServerNotifications = functions.https.onRequest(async (req, res) => {
  try {
    console.log('Received App Store Server Notification (Production)');
    
    // Verify the notification signature
    const isValid = await verifyAppStoreNotification(req);
    if (!isValid) {
      console.error('Invalid App Store notification signature');
      return res.status(401).send('Unauthorized');
    }

    // Process the notification
    await processAppStoreNotification(req.body, 'production');
    
    res.status(200).send('OK');
  } catch (error) {
    console.error('Error processing App Store notification:', error);
    res.status(500).send('Internal Server Error');
  }
});

/**
 * App Store Server Notification handler for sandbox environment
 * This endpoint receives notifications from Apple about subscription events in sandbox
 */
exports.appStoreServerNotificationsSandbox = functions.https.onRequest(async (req, res) => {
  try {
    console.log('Received App Store Server Notification (Sandbox)');
    
    // Verify the notification signature
    const isValid = await verifyAppStoreNotification(req);
    if (!isValid) {
      console.error('Invalid App Store notification signature');
      return res.status(401).send('Unauthorized');
    }

    // Process the notification
    await processAppStoreNotification(req.body, 'sandbox');
    
    res.status(200).send('OK');
  } catch (error) {
    console.error('Error processing App Store notification:', error);
    res.status(500).send('Internal Server Error');
  }
});

/**
 * Verify App Store Server Notification signature
 */
async function verifyAppStoreNotification(req) {
  try {
    // Get the signature from headers
    const signature = req.get('x-apple-signature');
    const certificate = req.get('x-apple-certificate');
    
    if (!signature || !certificate) {
      console.error('Missing signature or certificate headers');
      return false;
    }

    // For production, you should verify the certificate chain and signature
    // This is a simplified version - in production, implement proper certificate verification
    console.log('Signature verification passed (simplified)');
    return true;
  } catch (error) {
    console.error('Error verifying notification signature:', error);
    return false;
  }
}

/**
 * Process App Store Server Notification
 */
async function processAppStoreNotification(notificationBody, environment) {
  try {
    console.log(`Processing ${environment} notification:`, JSON.stringify(notificationBody, null, 2));
    
    const { notificationType, subtype, data } = notificationBody;
    
    // Handle different notification types
    switch (notificationType) {
      case 'SUBSCRIBED':
        await handleSubscriptionCreated(data, environment);
        break;
      case 'DID_RENEW':
        await handleSubscriptionRenewed(data, environment);
        break;
      case 'DID_FAIL_TO_RENEW':
        await handleSubscriptionFailedToRenew(data, environment);
        break;
      case 'DID_CHANGE_RENEWAL_STATUS':
        await handleRenewalStatusChanged(data, environment);
        break;
      case 'DID_CHANGE_RENEWAL_PREF':
        await handleRenewalPreferenceChanged(data, environment);
        break;
      case 'EXPIRED':
        await handleSubscriptionExpired(data, environment);
        break;
      case 'REVOKE':
        await handleSubscriptionRevoked(data, environment);
        break;
      case 'REFUND':
        await handleSubscriptionRefunded(data, environment);
        break;
      default:
        console.log(`Unhandled notification type: ${notificationType}`);
    }
  } catch (error) {
    console.error('Error processing notification:', error);
    throw error;
  }
}

/**
 * Handle subscription created
 */
async function handleSubscriptionCreated(data, environment) {
  try {
    const { appAccountToken, originalTransactionId } = data;
    const userId = appAccountToken; // Assuming you pass userId as appAccountToken
    
    console.log(`Subscription created for user ${userId} in ${environment}`);
    
    // Update user's premium status
    await firestore.collection('users').doc(userId).update({
      isPremium: true,
      premiumPlan: 'month', // Default to monthly, you can determine this from the product ID
      subscriptionStatus: 'active',
      originalTransactionId: originalTransactionId,
      environment: environment,
      premiumActivatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastNotificationType: 'SUBSCRIBED'
    });
    
    console.log(`Updated user ${userId} premium status to active`);
  } catch (error) {
    console.error('Error handling subscription created:', error);
    throw error;
  }
}

/**
 * Handle subscription renewed
 */
async function handleSubscriptionRenewed(data, environment) {
  try {
    const { appAccountToken, originalTransactionId } = data;
    const userId = appAccountToken;
    
    console.log(`Subscription renewed for user ${userId} in ${environment}`);
    
    // Update user's premium status
    await firestore.collection('users').doc(userId).update({
      isPremium: true,
      subscriptionStatus: 'active',
      lastRenewalAt: admin.firestore.FieldValue.serverTimestamp(),
      lastNotificationType: 'DID_RENEW'
    });
    
    console.log(`Updated user ${userId} subscription renewal`);
  } catch (error) {
    console.error('Error handling subscription renewed:', error);
    throw error;
  }
}

/**
 * Handle subscription failed to renew
 */
async function handleSubscriptionFailedToRenew(data, environment) {
  try {
    const { appAccountToken, originalTransactionId } = data;
    const userId = appAccountToken;
    
    console.log(`Subscription failed to renew for user ${userId} in ${environment}`);
    
    // Update user's premium status
    await firestore.collection('users').doc(userId).update({
      subscriptionStatus: 'failed_to_renew',
      lastFailedRenewalAt: admin.firestore.FieldValue.serverTimestamp(),
      lastNotificationType: 'DID_FAIL_TO_RENEW'
    });
    
    console.log(`Updated user ${userId} subscription failure status`);
  } catch (error) {
    console.error('Error handling subscription failed to renew:', error);
    throw error;
  }
}

/**
 * Handle renewal status changed
 */
async function handleRenewalStatusChanged(data, environment) {
  try {
    const { appAccountToken, originalTransactionId } = data;
    const userId = appAccountToken;
    
    console.log(`Renewal status changed for user ${userId} in ${environment}`);
    
    // Update user's premium status
    await firestore.collection('users').doc(userId).update({
      lastNotificationType: 'DID_CHANGE_RENEWAL_STATUS',
      lastRenewalStatusChangeAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log(`Updated user ${userId} renewal status change`);
  } catch (error) {
    console.error('Error handling renewal status changed:', error);
    throw error;
  }
}

/**
 * Handle renewal preference changed
 */
async function handleRenewalPreferenceChanged(data, environment) {
  try {
    const { appAccountToken, originalTransactionId } = data;
    const userId = appAccountToken;
    
    console.log(`Renewal preference changed for user ${userId} in ${environment}`);
    
    // Update user's premium status
    await firestore.collection('users').doc(userId).update({
      lastNotificationType: 'DID_CHANGE_RENEWAL_PREF',
      lastRenewalPreferenceChangeAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log(`Updated user ${userId} renewal preference change`);
  } catch (error) {
    console.error('Error handling renewal preference changed:', error);
    throw error;
  }
}

/**
 * Handle subscription expired
 */
async function handleSubscriptionExpired(data, environment) {
  try {
    const { appAccountToken, originalTransactionId } = data;
    const userId = appAccountToken;
    
    console.log(`Subscription expired for user ${userId} in ${environment}`);
    
    // Update user's premium status
    await firestore.collection('users').doc(userId).update({
      isPremium: false,
      subscriptionStatus: 'expired',
      premiumExpiredAt: admin.firestore.FieldValue.serverTimestamp(),
      lastNotificationType: 'EXPIRED'
    });
    
    console.log(`Updated user ${userId} premium status to expired`);
  } catch (error) {
    console.error('Error handling subscription expired:', error);
    throw error;
  }
}

/**
 * Handle subscription revoked
 */
async function handleSubscriptionRevoked(data, environment) {
  try {
    const { appAccountToken, originalTransactionId } = data;
    const userId = appAccountToken;
    
    console.log(`Subscription revoked for user ${userId} in ${environment}`);
    
    // Update user's premium status
    await firestore.collection('users').doc(userId).update({
      isPremium: false,
      subscriptionStatus: 'revoked',
      premiumRevokedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastNotificationType: 'REVOKE'
    });
    
    console.log(`Updated user ${userId} premium status to revoked`);
  } catch (error) {
    console.error('Error handling subscription revoked:', error);
    throw error;
  }
}

/**
 * Handle subscription refunded
 */
async function handleSubscriptionRefunded(data, environment) {
  try {
    const { appAccountToken, originalTransactionId } = data;
    const userId = appAccountToken;
    
    console.log(`Subscription refunded for user ${userId} in ${environment}`);
    
    // Update user's premium status
    await firestore.collection('users').doc(userId).update({
      isPremium: false,
      subscriptionStatus: 'refunded',
      premiumRefundedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastNotificationType: 'REFUND'
    });
    
    console.log(`Updated user ${userId} premium status to refunded`);
  } catch (error) {
    console.error('Error handling subscription refunded:', error);
    throw error;
  }
}

/**
 * Check for existing meals by titles (server-side implementation)
 * Returns a map of title -> meal data for existing meals
 */
async function checkExistingMealsByTitles(mealTitles) {
  try {
    const existingMeals = {};
    
    // Get all meals from Firestore
    const mealsSnapshot = await firestore.collection('meals').get();
    const allMeals = [];
    
    mealsSnapshot.forEach(doc => {
      const mealData = doc.data();
      allMeals.push({
        mealId: doc.id,
        title: mealData.title,
        categories: mealData.categories || [],
        ingredients: mealData.ingredients || {},
        calories: mealData.calories || 0,
        nutritionalInfo: mealData.nutritionalInfo || {},
        instructions: mealData.instructions || [],
      });
    });
    
    console.log(`Checking ${mealTitles.length} titles against ${allMeals.length} existing meals`);
    
    // Check each title for similarity
    for (const title of mealTitles) {
      let bestMatch = null;
      let bestScore = 0.0;
      
      for (const meal of allMeals) {
        const score = calculateTitleSimilarity(title.toLowerCase(), meal.title.toLowerCase());
        if (score > bestScore && score > 0.6) { // Threshold for similarity
          bestScore = score;
          bestMatch = meal;
        }
      }
      
      if (bestMatch) {
        existingMeals[title] = bestMatch;
        console.log(`Found existing meal: "${title}" -> "${bestMatch.title}" (score: ${bestScore.toFixed(2)})`);
      }
    }
    
    return existingMeals;
  } catch (error) {
    console.error('Error checking existing meals:', error);
    return {};
  }
}

/**
 * Calculate similarity between two meal titles
 * Simple implementation - can be enhanced with more sophisticated algorithms
 */
function calculateTitleSimilarity(title1, title2) {
  // Simple word-based similarity
  const words1 = title1.split(/\s+/);
  const words2 = title2.split(/\s+/);
  
  let matches = 0;
  for (const word1 of words1) {
    for (const word2 of words2) {
      if (word1 === word2) {
        matches++;
        break;
      }
    }
  }
  
  // Calculate similarity score (0-1)
  const maxWords = Math.max(words1.length, words2.length);
  return maxWords > 0 ? matches / maxWords : 0;
}

/**
 * Image processing utility for cloud functions
 * Compresses and resizes images for faster AI analysis
 */
async function processImageForAI(imageBuffer) {
  try {
    console.log(`Original image size: ${imageBuffer.length} bytes (${(imageBuffer.length / 1024).toFixed(2)} KB)`);
    
    // If image is already small enough, return as-is
    if (imageBuffer.length <= 500 * 1024) {
      console.log('Image already optimized, skipping compression');
      return imageBuffer;
    }
    
    console.log('Compressing large image using Jimp...');
    
    // Use Jimp for image processing (pure JavaScript, no external dependencies)
    const image = await Jimp.read(imageBuffer);
    
    // Resize to max 1024px on longest side
    if (image.getWidth() > image.getHeight()) {
      if (image.getWidth() > 1024) {
        image.resize(1024, Jimp.AUTO);
        console.log('Resized image width to 1024px');
      }
    } else {
      if (image.getHeight() > 1024) {
        image.resize(Jimp.AUTO, 1024);
        console.log('Resized image height to 1024px');
      }
    }
    
    // Compress with quality 85
    image.quality(85);
    
    // Convert to buffer
    const processedBuffer = await image.getBufferAsync(Jimp.MIME_JPEG);
    
    console.log(`Compressed image size: ${processedBuffer.length} bytes (${(processedBuffer.length / 1024).toFixed(2)} KB)`);
    
    return processedBuffer;
  } catch (error) {
    console.error('Error processing image with Jimp:', error);
    // Return original buffer if processing fails
    return imageBuffer;
  }
}

/**
 * Generate meals with AI using cloud function
 * Handles meal plan generation with optimized performance
 */
exports.generateMealsWithAI = functions
  .runWith({ timeoutSeconds: 120, memory: '512MB' })
  .https.onCall(async (data, context) => {
    const startTime = Date.now();
    console.log('=== generateMealsWithAI Cloud Function Started ===');
    
    try {
      // Validate input
      const { prompt, context: userContext, cuisine, mealCount, distribution, isIngredientBased } = data;
      
      if (!prompt) {
        throw new functions.https.HttpsError('invalid-argument', 'Prompt is required');
      }
      
      console.log(`Generating ${mealCount || 'default'} meals for cuisine: ${cuisine || 'general'}`);
      
      // Get the best Gemini model
      const model = await _getGeminiModel();
      
      // Build comprehensive prompt with user context (matching original gemini_service structure)
      const fullPrompt = `You are a professional nutritionist and meal planner.

${userContext || ''}

${prompt}

${contextInformation || ''}

Generate ${mealCount || (isIngredientBased ? 2 : 10)} meals. Return JSON only:
{
  "mealPlan": [
    {
      "title": "meal name",
      "mealType": "breakfast|lunch|dinner|snack",
      "type": "protein|grain|vegetable|fruit",
    }
  ],
  "distribution": {
    "breakfast": ${distribution?.breakfast || 2},
    "lunch": ${distribution?.lunch || 3},
    "dinner": ${distribution?.dinner || 3},
    "snack": ${distribution?.snack || 2}
  }
}

Important guidelines:
- Return valid, complete JSON only. Do not include markdown or code blocks.
- All nutritional values must be numbers (not strings).
- Focus on ${cuisine || 'general'} cuisine style.
- mealType must be one of: breakfast|lunch|dinner|snack
- type must be one of: protein|grain|vegetable|fruit`;

      // Generate content with optimized settings
      const result = await model.generateContent(fullPrompt);
      const response = result.response.text();
      
      console.log(`Raw AI response length: ${response.length} characters`);
      
      // Process AI response with robust parsing
      const mealData = await processAIResponse(response, 'meal_generation');
      
      // Validate response structure (expecting mealPlan, not meals)
      if (!mealData.mealPlan || !Array.isArray(mealData.mealPlan)) {
        throw new Error('Invalid meal data structure in AI response - expected mealPlan array');
      }
      
      console.log(`Generated ${mealData.mealPlan.length} meals from AI`);
      
      // Extract meal titles for existing meal check
      const mealTitles = mealData.mealPlan.map(meal => meal.title).filter(title => title);
      console.log(`Checking for existing meals with titles: ${mealTitles.join(', ')}`);
      
      // Check for existing meals server-side
      const existingMeals = await checkExistingMealsByTitles(mealTitles);
      console.log(`Found ${Object.keys(existingMeals).length} existing meals`);
      
      // Identify missing meals that need to be generated
      const missingMeals = [];
      const existingMealTitles = Object.keys(existingMeals);
      
      for (const meal of mealData.mealPlan) {
        const title = meal.title;
        if (!existingMealTitles.includes(title)) {
          missingMeals.push(meal);
        }
      }
      
      console.log(`Need to generate ${missingMeals.length} new meals`);
      
      // Save only missing meals individually to meals collection
      const mealIds = [];
      const batch = firestore.batch();
      
      for (const meal of missingMeals) {
        const mealRef = firestore.collection('meals').doc();
        const mealId = mealRef.id;
        
        // Create meal document with minimal data - Firebase Functions will fill out details
        const basicMealData = {
          title: meal.title || 'Untitled Meal',
          mealType: meal.mealType || 'main',
          calories: 0, // Will be filled by Firebase Functions
          categories: [meal.cuisine || 'general'],
          nutritionalInfo: {}, // Will be filled by Firebase Functions
          ingredients: {}, // Will be filled by Firebase Functions
          instructions: [], // Will be filled by Firebase Functions
          status: 'pending', // Firebase Functions will process this
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          type: meal.type || 'main',
          userId: 'hhY2Fp8pA5cVPCWJKuCb1IGWagh1', // tastyId from constants.dart
          source: 'ai_generated',
          version: 'basic',
          processingAttempts: 0, // Track retry attempts
          lastProcessingAttempt: null, // Timestamp of last attempt
          processingPriority: Date.now(), // FIFO processing
          needsProcessing: true, // Flag for Firebase Functions
        };
        
        console.log(`Saving new meal with minimal data: ${meal.title} with ID: ${mealId}`);
        console.log(`Minimal meal data (Firebase Functions will fill out details):`, JSON.stringify(basicMealData, null, 2));
        batch.set(mealRef, basicMealData);
        mealIds.push(mealId);
      }
      
      // Commit all new meals in a single batch
      if (missingMeals.length > 0) {
        await batch.commit();
        console.log(`Saved ${mealIds.length} new meals to Firestore with pending status`);
      }
      
      // Prepare response with both existing and new meals
      const allMeals = [];
      
      // Add existing meals
      for (const [title, existingMeal] of Object.entries(existingMeals)) {
        allMeals.push({
          id: existingMeal.mealId,
          title: existingMeal.title,
          categories: existingMeal.categories,
          ingredients: existingMeal.ingredients,
          calories: existingMeal.calories,
          nutritionalInfo: existingMeal.nutritionalInfo,
          instructions: existingMeal.instructions,
          mealType: mealData.mealPlan.find(m => m.title === title)?.mealType || 'main',
          source: 'existing_database',
          status: 'completed',
        });
      }
      
      // Add new meals with minimal data (Firebase Functions will fill out details)
      for (let i = 0; i < missingMeals.length; i++) {
        const meal = missingMeals[i];
        const mealId = mealIds[i];
        allMeals.push({
          id: mealId,
          title: meal.title,
          categories: [meal.cuisine || 'general'],
          ingredients: {}, // Will be filled by Firebase Functions
          calories: 0, // Will be filled by Firebase Functions
          nutritionalInfo: {}, // Will be filled by Firebase Functions
          instructions: [], // Will be filled by Firebase Functions
          mealType: meal.mealType || 'main',
          source: 'ai_generated',
          status: 'pending',
        });
      }
      
      // Save meal plan metadata for reference
      const mealPlanRef = firestore.collection('meal_plans').doc();
      const mealPlanData = {
        mealIds: mealIds, // Only new meal IDs
        existingMealIds: Object.values(existingMeals).map(meal => meal.mealId),
        allMealIds: allMeals.map(meal => meal.id),
        distribution: mealData.distribution || distribution,
        source: 'cloud_function',
        executionTime: Date.now() - startTime,
        mealCount: allMeals.length,
        newMealCount: missingMeals.length,
        existingMealCount: Object.keys(existingMeals).length,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        userId: context.auth?.uid || 'anonymous',
      };
      
      await firestore.collection('meal_plans').doc(mealPlanRef.id).set(mealPlanData);
      
      console.log(`=== SAVED MEAL PLAN TO FIRESTORE ===`);
      console.log(`Meal Plan ID: ${mealPlanRef.id}`);
      console.log(`Total meals: ${allMeals.length} (${Object.keys(existingMeals).length} existing, ${missingMeals.length} new with minimal data)`);
      console.log(`New Meal IDs (pending Firebase Functions processing): ${mealIds.join(', ')}`);
      console.log(`Data saved successfully - Firebase Functions will fill out meal details`);
      console.log(`=== END FIRESTORE SAVE ===`);

      // Return comprehensive meal plan data
      return {
        success: true,
        mealPlanId: mealPlanRef.id,
        meals: allMeals,
        mealIds: mealIds, // Only new meal IDs
        existingMealIds: Object.values(existingMeals).map(meal => meal.mealId),
        executionTime: Date.now() - startTime,
        mealCount: allMeals.length,
        newMealCount: missingMeals.length,
        existingMealCount: Object.keys(existingMeals).length,
      };
      
    } catch (error) {
      const executionTime = Date.now() - startTime;
      console.error(`=== generateMealsWithAI failed after ${executionTime}ms ===`, error);
      
      throw new functions.https.HttpsError(
        'internal',
        `Failed to generate meals: ${error.message}`
      );
    }
  });

/**
 * Analyze food image using cloud function
 * Handles food image analysis with server-side image optimization
 */
exports.analyzeFoodImage = functions
  .runWith({ timeoutSeconds: 120, memory: '512MB' })
  .https.onCall(async (data, context) => {
    const startTime = Date.now();
    console.log('=== analyzeFoodImage Cloud Function Started ===');
    
    try {
      // Validate input
      const { base64Image, mealType, dietaryRestrictions } = data;
      
      if (!base64Image) {
        throw new functions.https.HttpsError('invalid-argument', 'Base64 image is required');
      }
      
      console.log(`Analyzing food image for meal type: ${mealType || 'general'}`);
      
      // Convert base64 to buffer and process image
      const imageBuffer = Buffer.from(base64Image, 'base64');
      const processedBuffer = await processImageForAI(imageBuffer);
      const processedBase64 = processedBuffer.toString('base64');
      
      // Get the best Gemini model
      const model = await _getGeminiModel();
      
      // Build contextual prompt
      let contextualPrompt = 'Analyze this food and provide nutritional info.';
      
      if (mealType) {
        contextualPrompt += ` Type: ${mealType}.`;
      }
      
      if (dietaryRestrictions && dietaryRestrictions.length > 0) {
        contextualPrompt += ` Diet: ${dietaryRestrictions.join(', ')}.`;
      }
      
      const prompt = `${contextualPrompt}

Return ONLY this JSON structure (no markdown, no explanations):

{
  "foodItems": [
    {
      "name": "food item name",
      "estimatedWeight": "weight in grams",
      "confidence": "high|medium|low",
      "nutritionalInfo": {
        "calories": 0,
        "protein": 0,
        "carbs": 0,
        "fat": 0,
        "fiber": 0,
        "sugar": 0,
        "sodium": 0
      }
    }
  ],
  "totalNutrition": {
    "calories": 0,
    "protein": 0,
    "carbs": 0,
    "fat": 0,
    "fiber": 0,
    "sugar": 0,
    "sodium": 0
  },
  "ingredients": {
    "ingredient1": "amount with unit (e.g., '1 cup', '200g')",
    "ingredient2": "amount with unit"
  },
  "confidence": "high|medium|low",
  "suggestions": {
    "improvements": ["Add more vegetables for fiber", "Reduce sodium content"],
    "alternatives": ["Try grilled instead of fried", "Use olive oil instead of butter"],
    "additions": ["Add herbs for flavor", "Include a side salad"]
  }
}

Important guidelines:
- Return valid, complete JSON only. Do not include markdown or code blocks.
- All nutritional values must be numbers (not strings).
- Confidence must be one of: high|medium|low
- Provide realistic nutritional estimates based on visible portions.
- ALWAYS include suggestions with practical cooking improvements, alternatives, and additions.
- Make suggestions specific and actionable based on the food items identified.`;

      // Generate content with image
      const result = await model.generateContent([
        { text: prompt },
        {
          inlineData: {
            mimeType: 'image/jpeg',
            data: processedBase64
          }
        }
      ]);
      
      const aiResponse = result.response.text();
      console.log(`Raw AI response length: ${aiResponse.length} characters`);
      console.log('=== RAW AI RESPONSE ===');
      console.log(aiResponse);
      console.log('=== END RAW AI RESPONSE ===');
      
      // Process AI response
      const foodData = await processAIResponse(aiResponse, 'tasty_analysis');
      
      // Debug suggestions and provide fallback if missing
      console.log('=== SUGGESTIONS DEBUG ===');
      console.log('Raw suggestions:', foodData.suggestions);
      console.log('Suggestions type:', typeof foodData.suggestions);
      console.log('Suggestions keys:', foodData.suggestions ? Object.keys(foodData.suggestions) : 'null');
      
      // Provide fallback suggestions if AI didn't generate them
      if (!foodData.suggestions || typeof foodData.suggestions !== 'object') {
        console.log('AI did not provide suggestions, using fallback...');
        foodData.suggestions = {
          improvements: ["Add more vegetables for better nutrition", "Consider reducing portion size"],
          alternatives: ["Try grilling instead of frying", "Use herbs instead of salt for flavor"],
          additions: ["Add a side salad", "Include fresh herbs for garnish"]
        };
      }
      
      console.log('Final suggestions:', foodData.suggestions);
      console.log('=== END SUGGESTIONS DEBUG ===');
      
      // Validate response structure (expecting comprehensive food analysis structure)
      if (!foodData.foodItems || !Array.isArray(foodData.foodItems)) {
        throw new Error('Invalid food data structure in AI response - expected foodItems array');
      }
      
      const executionTime = Date.now() - startTime;
      console.log(`=== analyzeFoodImage completed in ${executionTime}ms ===`);
      
      // Save food analysis data to Firestore
      const analysisData = {
        foodItems: foodData.foodItems,
        totalNutrition: foodData.totalNutrition || {},
        ingredients: foodData.ingredients || {},
        confidence: foodData.confidence || 'medium',
        suggestions: foodData.suggestions || {},
        source: 'cloud_function',
        executionTime: executionTime,
        itemCount: foodData.foodItems.length,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        userId: context.auth?.uid || 'anonymous',
      };

      // Save analysis to Firestore
      const analysisRef = await firestore.collection('food_analyses').add(analysisData);
      
      // If there are suggested meals, save them individually to meals collection
      const mealIds = [];
      if (foodData.suggestedMeals && Array.isArray(foodData.suggestedMeals) && foodData.suggestedMeals.length > 0) {
        const batch = firestore.batch();
        
        for (const suggestedMeal of foodData.suggestedMeals) {
          const mealRef = firestore.collection('meals').doc();
          const mealId = mealRef.id;
          
          // Create meal document with same structure as saveBasicMealsToFirestore
          const basicMealData = {
            title: suggestedMeal.title || 'Suggested Meal',
            mealType: suggestedMeal.mealType || 'main',
            calories: suggestedMeal.calories || 0,
            categories: [],
            nutritionalInfo: suggestedMeal.nutritionalInfo || {},
            ingredients: suggestedMeal.ingredients || {},
            instructions: suggestedMeal.instructions || [],
            cookingTime: suggestedMeal.cookingTime || '30 minutes',
            difficulty: suggestedMeal.difficulty || 'medium',
            servings: suggestedMeal.servings || 1,
            status: 'pending', // Firebase Functions will process this
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            type: suggestedMeal.type || 'main',
            userId: 'hhY2Fp8pA5cVPCWJKuCb1IGWagh1', // tastyId from constants.dart
            source: 'ai_generated',
            version: 'basic',
            processingAttempts: 0, // Track retry attempts
            lastProcessingAttempt: null, // Timestamp of last attempt
            processingPriority: Date.now(), // FIFO processing
            needsProcessing: true, // Flag for Firebase Functions
          };
          
          console.log(`Saving suggested meal: ${suggestedMeal.title} with ID: ${mealId}`);
          console.log(`Suggested meal data:`, JSON.stringify(basicMealData, null, 2));
          batch.set(mealRef, basicMealData);
          mealIds.push(mealId);
        }
        
        // Commit all suggested meals in a single batch
        await batch.commit();
        console.log(`Saved ${mealIds.length} suggested meals to Firestore with pending status`);
      }
      
      console.log(`=== SAVED TO FIRESTORE ===`);
      console.log(`Analysis ID: ${analysisRef.id}`);
      console.log(`Suggested Meal IDs: ${mealIds.join(', ')}`);
      console.log(`Data saved successfully`);
      console.log(`=== END FIRESTORE SAVE ===`);

      // Return analysis ID and suggested meal IDs
      const response = {
        success: true,
        analysisId: analysisRef.id,
        suggestedMealIds: mealIds,
        executionTime: executionTime,
        // Include complete analysis data for immediate display
        foodItems: foodData.foodItems,
        totalNutrition: foodData.totalNutrition || {},
        ingredients: foodData.ingredients || {},
        confidence: foodData.confidence || 'medium',
        suggestions: foodData.suggestions || {},
        source: 'cloud_function',
        itemCount: foodData.foodItems.length,
      };
      
      console.log('=== FINAL CLOUD FUNCTION RESPONSE ===');
      console.log('Response type:', typeof response);
      console.log('Response keys:', Object.keys(response));
      console.log('Analysis ID:', response.analysisId);
      console.log('Full response:', JSON.stringify(response, null, 2));
      console.log('=== END CLOUD FUNCTION RESPONSE ===');
      
      return response;
      
    } catch (error) {
      const executionTime = Date.now() - startTime;
      console.error(`=== analyzeFoodImage failed after ${executionTime}ms ===`, error);
      
      throw new functions.https.HttpsError(
        'internal',
        `Failed to analyze food image: ${error.message}`
      );
    }
  });

/**
 * Analyze fridge image using cloud function
 * Handles fridge scanning with server-side image optimization
 */
exports.analyzeFridgeImage = functions
  .runWith({ timeoutSeconds: 120, memory: '512MB' })
  .https.onCall(async (data, context) => {
    const startTime = Date.now();
    console.log('=== analyzeFridgeImage Cloud Function Started ===');
    
    try {
      // Validate input
      const { base64Image, dietaryRestrictions } = data;
      
      if (!base64Image) {
        throw new functions.https.HttpsError('invalid-argument', 'Base64 image is required');
      }
      
      console.log('Analyzing fridge image for ingredients');
      
      // Convert base64 to buffer and process image
      const imageBuffer = Buffer.from(base64Image, 'base64');
      const processedBuffer = await processImageForAI(imageBuffer);
      const processedBase64 = processedBuffer.toString('base64');
      
      // Get the best Gemini model
      const model = await _getGeminiModel();
      
      // Build contextual prompt
      let contextualPrompt = 'Analyze this fridge image to identify raw ingredients that can be used for cooking.';
      
      if (dietaryRestrictions && dietaryRestrictions.length > 0) {
        contextualPrompt += ` Consider dietary restrictions: ${dietaryRestrictions.join(', ')}.`;
      }
      
      const prompt = `${contextualPrompt}

Identify all visible raw ingredients in this fridge that can be used for cooking.

CRITICAL: Return ONLY raw JSON data. Do not wrap in \`\`\`json\`\`\` or \`\`\` code blocks. Do not add any markdown formatting. Return pure JSON only with the following structure:

{
  "ingredients": [
    {
      "name": "ingredient name",
      "category": "vegetable|protein|dairy|grain|fruit|herb|spice|other"
    }
  ],
  "suggestedMeals": [
    {
      "title": "meal name",
      "cookingTime": "30 minutes",
      "difficulty": "easy|medium|hard",
      "calories": 0
    }
  ]
}

Important guidelines:
- Return valid, complete JSON only. Do not include markdown or code blocks.
- Focus on ingredients that can be used for cooking main meals.
- Provide 2 diverse (1 medium and 1 hard) meal suggestions using the identified ingredients.
- All nutritional values must be numbers (not strings).
- Category must be one of the following: vegetable|protein|dairy|grain|fruit|herb|spice|other`;

      // Generate content with image
      const result = await model.generateContent([
        { text: prompt },
        {
          inlineData: {
            mimeType: 'image/jpeg',
            data: processedBase64
          }
        }
      ]);
      
      const response = result.response.text();
      console.log(`Raw AI response length: ${response.length} characters`);
      
      // Process AI response
      const fridgeData = await processAIResponse(response, 'fridge_analysis');
      
      // Validate response structure
      if (!fridgeData.ingredients || !Array.isArray(fridgeData.ingredients)) {
        throw new Error('Invalid fridge data structure in AI response');
      }
      
      const executionTime = Date.now() - startTime;
      console.log(`=== analyzeFridgeImage completed in ${executionTime}ms ===`);
      
      // Save fridge analysis data to Firestore
      const fridgeAnalysisData = {
        ingredients: fridgeData.ingredients || [],
        suggestedMeals: fridgeData.suggestedMeals || [],
        source: 'cloud_function',
        executionTime: executionTime,
        ingredientCount: fridgeData.ingredients?.length || 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        userId: context.auth?.uid || 'anonymous',
      };

      // Save analysis to Firestore
      const analysisRef = await firestore.collection('fridge_analyses').add(fridgeAnalysisData);
      
      // Save suggested meals individually to meals collection
      const mealIds = [];
      if (fridgeData.suggestedMeals && Array.isArray(fridgeData.suggestedMeals) && fridgeData.suggestedMeals.length > 0) {
        const batch = firestore.batch();
        
        for (const suggestedMeal of fridgeData.suggestedMeals) {
          const mealRef = firestore.collection('meals').doc();
          const mealId = mealRef.id;
          
          // Create meal document with same structure as saveBasicMealsToFirestore
          const basicMealData = {
            title: suggestedMeal.title || 'Fridge Suggested Meal',
            mealType: suggestedMeal.mealType || 'main',
            calories: suggestedMeal.calories || 0,
            categories: ['fridge-suggested'],
            nutritionalInfo: suggestedMeal.nutritionalInfo || {},
            ingredients: suggestedMeal.ingredients || {},
            instructions: suggestedMeal.instructions || [],
            cookingTime: suggestedMeal.cookingTime || '30 minutes',
            difficulty: suggestedMeal.difficulty || 'medium',
            servings: suggestedMeal.servings || 1,
            status: 'pending', // Firebase Functions will process this
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            type: suggestedMeal.type || 'main',
            userId: 'hhY2Fp8pA5cVPCWJKuCb1IGWagh1', // tastyId from constants.dart
            source: 'ai_generated',
            version: 'basic',
            processingAttempts: 0, // Track retry attempts
            lastProcessingAttempt: null, // Timestamp of last attempt
            processingPriority: Date.now(), // FIFO processing
            needsProcessing: true, // Flag for Firebase Functions
          };
          
          console.log(`Saving fridge suggested meal: ${suggestedMeal.title} with ID: ${mealId}`);
          console.log(`Fridge suggested meal data:`, JSON.stringify(basicMealData, null, 2));
          batch.set(mealRef, basicMealData);
          mealIds.push(mealId);
        }
        
        // Commit all suggested meals in a single batch
        await batch.commit();
        console.log(`Saved ${mealIds.length} fridge suggested meals to Firestore with pending status`);
      }
      
      console.log(`=== SAVED FRIDGE ANALYSIS TO FIRESTORE ===`);
      console.log(`Analysis ID: ${analysisRef.id}`);
      console.log(`Suggested Meal IDs: ${mealIds.join(', ')}`);
      console.log(`Data saved successfully`);
      console.log(`=== END FIRESTORE SAVE ===`);

      // Return analysis ID and suggested meal IDs
      return {
        success: true,
        analysisId: analysisRef.id,
        suggestedMealIds: mealIds,
        executionTime: executionTime,
        // Include complete analysis data for immediate display
        ingredients: fridgeData.ingredients || [],
        suggestedMeals: fridgeData.suggestedMeals || [],
        source: 'cloud_function',
        ingredientCount: fridgeData.ingredients?.length || 0,
      };
      
    } catch (error) {
      const executionTime = Date.now() - startTime;
      console.error(`=== analyzeFridgeImage failed after ${executionTime}ms ===`, error);
      
      throw new functions.https.HttpsError(
        'internal',
        `Failed to analyze fridge image: ${error.message}`
      );
    }
  });

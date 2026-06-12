import { initializeApp } from "firebase/app";
import { getDatabase } from "firebase/database";

const firebaseConfig = {
  apiKey: "AIzaSyCCFPugxPzZIih2wIC7W4Vqcj-X8S2_Tkk",
  authDomain: "giveme-5e950.firebaseapp.com",
  databaseURL: "https://giveme-5e950-default-rtdb.firebaseio.com",
  projectId: "giveme-5e950",
  storageBucket: "giveme-5e950.appspot.com",
  messagingSenderId: "1032501750236",
  appId: "1:1032501750236:web:02563becdc60bab98f0719",
  measurementId: "G-QDVPGH1CD8"
};

const app = initializeApp(firebaseConfig);
export const db = getDatabase(app);

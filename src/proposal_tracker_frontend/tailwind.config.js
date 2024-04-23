/** @type {import('tailwindcss').Config} */
import defaultTheme from "tailwindcss/defaultTheme";

export default {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      fontFamily: {
        sans: ["Work Sans", ...defaultTheme.fontFamily.sans],
      },
      colors: {
        primary: {
          light: "#b8edff",
          DEFAULT: "#0099CC",
          hover: "#0086b3",
        }, // codegov blue
        secondary: "#0f172a", // codegov dark blue
      },
      textColor: {
        primary: "#0f172a", // codegov dark blue
      },
    },
  },
  plugins: [],
};

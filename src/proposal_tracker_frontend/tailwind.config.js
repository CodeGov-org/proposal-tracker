/** @type {import('tailwindcss').Config} */
import defaultTheme from "tailwindcss/defaultTheme";

const projectColors = {
  primary: {
    light: "#b8edff",
    DEFAULT: "#0099CC", // codegov blue
    dark: "#0086b3",
  },
  secondary: "#0f172a", // codegov dark blue
};

export default {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      fontFamily: {
        sans: ["Work Sans", ...defaultTheme.fontFamily.sans],
      },
      colors: projectColors,
      textColor: projectColors,
    },
  },
  plugins: [],
};

export const PrimaryButton = ({ text, onClick }) => {
  return (
    <button
      type="button"
      className="rounded-lg bg-primary px-4 py-2 text-center text-sm text-white hover:bg-primary-hover"
      onClick={onClick}
    >
      {text}
    </button>
  );
};

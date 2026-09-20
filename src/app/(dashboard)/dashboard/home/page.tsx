import PageMap from "./PageMap";
import styles from "./home.module.css";

export const metadata = { title: "Home page" };

export default function HomeHubPage() {
  return (
    <>
      <header className={styles.head}>
        <h1>Home page</h1>
        <p className={styles.lede}>
          The fifteen sections a visitor scrolls through, in order. Drag a section to move it,
          hide one to take it off the page without deleting anything, or open one to edit what it
          says.
        </p>
      </header>

      <PageMap />

      <p className={styles.aside}>
        The header, footer, SEO details and statistics are in the sidebar rather than this list.
        They appear on more than this page, or are not a position on it, so they cannot be
        reordered.
      </p>
    </>
  );
}

import Link from "next/link";
import { notFound } from "next/navigation";

import { CONTENT_PAGE_ORDER, resolvePage } from "@/server/cms/pages";

import PageMap from "../../home/PageMap";
import styles from "../../home/home.module.css";

interface Params {
  params: Promise<{ page: string }>;
}

export function generateStaticParams() {
  return CONTENT_PAGE_ORDER.map((page) => ({ page }));
}

export async function generateMetadata({ params }: Params) {
  return { title: resolvePage((await params).page)?.label ?? "Page" };
}

/** The hub of an inner page: its sections in render order, and its SEO. */
export default async function PageHub({ params }: Params) {
  const slug = (await params).page;
  const page = resolvePage(slug);
  if (!page) notFound();

  return (
    <>
      <header className={styles.head}>
        <h1>{page.label}</h1>
        <p className={styles.lede}>
          The sections of {page.route}, in the order a visitor meets them. Drag one to move it,
          hide one to take it off the page without deleting anything, or open one to edit every
          field it shows. <Link href={`/dashboard/pages/${slug}/seo`}>Edit the page&apos;s SEO</Link>.
        </p>
      </header>

      <PageMap page={slug} />
    </>
  );
}

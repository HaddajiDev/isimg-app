export const metadata = {
  title: "Politique de confidentialité — ISIMG Étudiant",
};

const LAST_UPDATED = "8 août 2026";
const CONTACT_EMAIL = "ahmedhaddajiahmed@gmail.com";

function Section({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className="flex flex-col gap-3">
      <h2 className="text-xl font-semibold text-zinc-950 dark:text-zinc-50">
        {title}
      </h2>
      <div className="flex flex-col gap-3 text-base leading-7 text-zinc-700 dark:text-zinc-300">
        {children}
      </div>
    </section>
  );
}

export default function Home() {
  return (
    <div className="flex flex-1 justify-center bg-zinc-50 font-sans dark:bg-black">
      <main className="flex w-full max-w-2xl flex-col gap-10 px-6 py-16 sm:px-8">
        <header className="flex flex-col gap-2 border-b border-zinc-200 pb-8 dark:border-zinc-800">
          <p className="text-sm font-medium uppercase tracking-wide text-zinc-500 dark:text-zinc-500">
            ISIMG Étudiant (non officiel)
          </p>
          <h1 className="text-3xl font-bold tracking-tight text-zinc-950 dark:text-zinc-50">
            Politique de confidentialité
          </h1>
          <p className="text-sm text-zinc-500 dark:text-zinc-500">
            Dernière mise à jour : {LAST_UPDATED}
          </p>
        </header>

        <p className="text-base leading-7 text-zinc-700 dark:text-zinc-300">
          <strong>ISIMG Étudiant</strong> est une application non officielle,
          développée de manière indépendante par un étudiant, qui permet de
          consulter son emploi du temps, ses notes et son profil sur
          l&rsquo;intranet de l&rsquo;ISIMG (isimg.rnu.tn). Elle n&rsquo;est
          affiliée ni à l&rsquo;ISIMG, ni à l&rsquo;Université de Gabès, ni au
          Ministère de l&rsquo;Enseignement Supérieur, et n&rsquo;est ni
          développée ni approuvée par ces derniers.
        </p>

        <Section title="Aucun serveur, aucune base de données">
          <p>
            Cette application ne dispose d&rsquo;aucun serveur backend et
            n&rsquo;envoie, ne stocke ni ne transmet vos données à qui que ce
            soit d&rsquo;autre que l&rsquo;ISIMG lui-même. L&rsquo;application
            se connecte directement, depuis votre téléphone, au site
            isimg.rnu.tn — exactement comme le ferait votre navigateur.
          </p>
          <p>
            Le développeur de cette application n&rsquo;a accès à aucune de
            vos données : ni identifiants, ni notes, ni emploi du temps.
          </p>
        </Section>

        <Section title="Données collectées et leur usage">
          <p>
            <strong>Identifiants ISIMG (nom d&rsquo;utilisateur et mot de
            passe).</strong> Utilisés uniquement pour vous connecter à
            isimg.rnu.tn. Si vous activez la connexion automatique, ils sont
            chiffrés et stockés uniquement sur votre appareil, via le système
            de stockage sécurisé natif d&rsquo;Android (Android Keystore).
            Ils ne quittent jamais votre téléphone, sauf pour être envoyés au
            site de l&rsquo;ISIMG lors de la connexion.
          </p>
          <p>
            <strong>Session et cookies de connexion.</strong> Stockés
            localement et chiffrés sur votre appareil, pour éviter de vous
            reconnecter à chaque ouverture de l&rsquo;application.
          </p>
          <p>
            <strong>Emploi du temps, notes et informations de profil.</strong>{" "}
            Récupérés directement depuis isimg.rnu.tn et affichés dans
            l&rsquo;application. Une copie de votre emploi du temps de la
            semaine est conservée localement pour permettre une consultation
            hors connexion.
          </p>
          <p>
            <strong>Notes simulées (facultatif).</strong> Si vous saisissez
            vous-même des notes provisoires pour estimer une moyenne, elles
            sont stockées uniquement sur votre appareil et n&rsquo;ont aucun
            effet sur vos notes officielles.
          </p>
        </Section>

        <Section title="Service tiers : génération d'avatar">
          <p>
            Pour afficher un avatar sur votre profil, l&rsquo;application
            envoie un identifiant dérivé de votre nom (et non votre nom en
            clair) au service{" "}
            <a
              href="https://www.dicebear.com/"
              className="font-medium text-zinc-950 underline dark:text-zinc-50"
            >
              DiceBear
            </a>{" "}
            (api.dicebear.com), qui génère une image d&rsquo;avatar. Ce
            service tiers peut recevoir votre adresse IP dans le cadre normal
            d&rsquo;une requête réseau. Aucune autre information
            n&rsquo;est partagée avec ce service.
          </p>
        </Section>

        <Section title="Ce que nous ne faisons pas">
          <ul className="list-disc pl-5 [&>li]:mt-1">
            <li>Aucune publicité et aucun système de suivi publicitaire.</li>
            <li>
              Aucun outil d&rsquo;analyse ou de mesure d&rsquo;audience
              tiers.
            </li>
            <li>
              Aucune vente, location ou partage de vos données avec des
              tiers.
            </li>
            <li>
              Aucun compte n&rsquo;est créé par l&rsquo;application : elle
              utilise uniquement votre compte ISIMG existant.
            </li>
          </ul>
        </Section>

        <Section title="Conservation et suppression des données">
          <p>
            Toutes les données mentionnées ci-dessus restent sur votre
            appareil. Elles sont supprimées automatiquement si vous videz les
            données de l&rsquo;application ou la désinstallez. Vous pouvez
            également vous déconnecter à tout moment depuis
            l&rsquo;application pour effacer les identifiants et la session
            enregistrés.
          </p>
        </Section>

        <Section title="Sécurité">
          <p>
            Les échanges avec isimg.rnu.tn utilisent le chiffrement HTTPS.
            Les identifiants et sessions stockés sur l&rsquo;appareil sont
            protégés par le stockage sécurisé natif d&rsquo;Android, adossé
            au matériel de votre téléphone.
          </p>
        </Section>

        <Section title="Public visé">
          <p>
            Cette application est destinée aux étudiants de l&rsquo;ISIMG et
            n&rsquo;est pas destinée aux enfants de moins de 13 ans.
          </p>
        </Section>

        <Section title="Modifications de cette politique">
          <p>
            Cette politique peut être mise à jour si le fonctionnement de
            l&rsquo;application évolue. La date de dernière mise à jour en
            haut de cette page reflète la version en vigueur.
          </p>
        </Section>

        <Section title="Contact">
          <p>
            Pour toute question concernant cette politique ou
            l&rsquo;application, vous pouvez écrire à{" "}
            <a
              href={`mailto:${CONTACT_EMAIL}`}
              className="font-medium text-zinc-950 underline dark:text-zinc-50"
            >
              {CONTACT_EMAIL}
            </a>
            .
          </p>
        </Section>
      </main>
    </div>
  );
}

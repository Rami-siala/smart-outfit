import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  const AppLocalizations(this.locale);

  static const supportedLocales = [
    Locale('en'),
    Locale('fr'),
    Locale('it'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final localizations =
        Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(localizations != null, 'AppLocalizations not found in context');
    return localizations!;
  }

  static final Map<String, Map<String, String>> _values = {
    'en': {
      'appTitle': 'Smart Outfit',
      'accountSettings': 'Account Settings',
      'profile': 'Profile',
      'editProfile': 'Edit Profile',
      'changePhotoNameDetails': 'Change your photo, name, and personal details.',
      'account': 'Account',
      'accountSubtitle': 'Update your personal details and profile basics.',
      'preferences': 'Preferences',
      'preferencesSubtitle':
          'Shape the profile details used in recommendations.',
      'security': 'Security',
      'securitySubtitle': 'Protect your account with password updates.',
      'changePassword': 'Change Password',
      'changePasswordSubtitle':
          'Update your password any time for better security.',
      'language': 'Language',
      'profileImageRemoved': 'Profile image removed',
      'settingsUpdated': 'Settings updated successfully',
      'removeProfileImage': 'Remove Profile Image',
      'removeProfileImageConfirmTitle': 'Remove profile image',
      'removeProfileImageConfirmMessage':
          'Do you want to remove your current profile image?',
      'cancel': 'Cancel',
      'remove': 'Remove',
      'logout': 'Logout',
      'logoutConfirmTitle': 'Logout',
      'logoutConfirmMessage': 'Are you sure you want to log out?',
      'saveChanges': 'Save Changes',
      'fullName': 'Full name',
      'email': 'Email',
      'height': 'Height (cm)',
      'weight': 'Weight (kg)',
      'skinTone': 'Skin tone',
      'bodyShape': 'Body shape',
      'currentPassword': 'Current password',
      'newPassword': 'New password',
      'confirmPassword': 'Confirm new password',
      'yourProfile': 'Your profile',
      'addYourEmail': 'Add your email',
      'age': 'Age',
      'languageSaved': 'Language updated',
      'loading': 'Loading...',
      'settingsError': 'Something went wrong',
    },
    'fr': {
      'appTitle': 'Smart Outfit',
      'accountSettings': 'Parametres du compte',
      'profile': 'Profil',
      'editProfile': 'Modifier le profil',
      'changePhotoNameDetails':
          'Modifiez votre photo, votre nom et vos informations personnelles.',
      'account': 'Compte',
      'accountSubtitle':
          'Mettez a jour vos informations personnelles et votre profil.',
      'preferences': 'Preferences',
      'preferencesSubtitle':
          'Ajustez les details du profil utilises dans les recommandations.',
      'security': 'Securite',
      'securitySubtitle':
          'Protegez votre compte avec des mises a jour de mot de passe.',
      'changePassword': 'Changer le mot de passe',
      'changePasswordSubtitle':
          'Mettez a jour votre mot de passe a tout moment.',
      'language': 'Langue',
      'profileImageRemoved': 'Image de profil supprimee',
      'settingsUpdated': 'Parametres mis a jour avec succes',
      'removeProfileImage': 'Supprimer l image de profil',
      'removeProfileImageConfirmTitle': 'Supprimer l image de profil',
      'removeProfileImageConfirmMessage':
          'Voulez-vous supprimer votre image de profil actuelle ?',
      'cancel': 'Annuler',
      'remove': 'Supprimer',
      'logout': 'Deconnexion',
      'logoutConfirmTitle': 'Deconnexion',
      'logoutConfirmMessage': 'Voulez-vous vraiment vous deconnecter ?',
      'saveChanges': 'Enregistrer les modifications',
      'fullName': 'Nom complet',
      'email': 'E-mail',
      'height': 'Taille (cm)',
      'weight': 'Poids (kg)',
      'skinTone': 'Teint',
      'bodyShape': 'Morphologie',
      'currentPassword': 'Mot de passe actuel',
      'newPassword': 'Nouveau mot de passe',
      'confirmPassword': 'Confirmer le mot de passe',
      'yourProfile': 'Votre profil',
      'addYourEmail': 'Ajoutez votre e-mail',
      'age': 'Age',
      'languageSaved': 'Langue mise a jour',
      'loading': 'Chargement...',
      'settingsError': 'Une erreur est survenue',
    },
    'it': {
      'appTitle': 'Smart Outfit',
      'accountSettings': 'Impostazioni account',
      'profile': 'Profilo',
      'editProfile': 'Modifica profilo',
      'changePhotoNameDetails':
          'Modifica foto, nome e dettagli personali.',
      'account': 'Account',
      'accountSubtitle':
          'Aggiorna i tuoi dati personali e le basi del profilo.',
      'preferences': 'Preferenze',
      'preferencesSubtitle':
          'Definisci i dettagli del profilo usati nei consigli.',
      'security': 'Sicurezza',
      'securitySubtitle':
          'Proteggi il tuo account con aggiornamenti della password.',
      'changePassword': 'Cambia password',
      'changePasswordSubtitle':
          'Aggiorna la password in qualsiasi momento.',
      'language': 'Lingua',
      'profileImageRemoved': 'Immagine profilo rimossa',
      'settingsUpdated': 'Impostazioni aggiornate con successo',
      'removeProfileImage': 'Rimuovi immagine profilo',
      'removeProfileImageConfirmTitle': 'Rimuovi immagine profilo',
      'removeProfileImageConfirmMessage':
          'Vuoi rimuovere l immagine del profilo attuale?',
      'cancel': 'Annulla',
      'remove': 'Rimuovi',
      'logout': 'Esci',
      'logoutConfirmTitle': 'Esci',
      'logoutConfirmMessage': 'Sei sicuro di voler uscire?',
      'saveChanges': 'Salva modifiche',
      'fullName': 'Nome completo',
      'email': 'Email',
      'height': 'Altezza (cm)',
      'weight': 'Peso (kg)',
      'skinTone': 'Tono della pelle',
      'bodyShape': 'Forma del corpo',
      'currentPassword': 'Password attuale',
      'newPassword': 'Nuova password',
      'confirmPassword': 'Conferma password',
      'yourProfile': 'Il tuo profilo',
      'addYourEmail': 'Aggiungi la tua email',
      'age': 'Eta',
      'languageSaved': 'Lingua aggiornata',
      'loading': 'Caricamento...',
      'settingsError': 'Si e verificato un errore',
    },
  };

  String t(String key) {
    final lang = _values[locale.languageCode] ?? _values['en']!;
    return lang[key] ?? _values['en']![key] ?? key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales
      .any((supported) => supported.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

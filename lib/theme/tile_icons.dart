import 'package:flutter/material.dart';

/// A curated palette of icons for the tile editor.
///
/// Deliberately a hand-picked set rather than the whole Material catalogue:
/// AAC boards need clear, unambiguous symbols, and a short list is far easier
/// to choose from than thousands of near-duplicates. Grouped loosely by need —
/// food & drink, body & health, people & feelings, actions, places, everyday
/// objects — so a caregiver can find something quickly. All are const so they
/// stay cheap to reference.
const List<IconData> kTileIconChoices = <IconData>[
  // Food & drink
  Icons.restaurant_rounded,
  Icons.local_cafe_rounded,
  Icons.local_drink_rounded,
  Icons.icecream_rounded,
  Icons.cake_rounded,
  Icons.cookie_rounded,
  // Body & health
  Icons.healing_rounded,
  Icons.medical_services_rounded,
  Icons.medication_rounded,
  Icons.wc_rounded,
  Icons.bedtime_rounded,
  Icons.thermostat_rounded,
  // People & feelings
  Icons.sentiment_satisfied_rounded,
  Icons.sentiment_dissatisfied_rounded,
  Icons.favorite_rounded,
  Icons.family_restroom_rounded,
  Icons.person_rounded,
  Icons.volunteer_activism_rounded,
  // Communication
  Icons.check_rounded,
  Icons.close_rounded,
  Icons.support_rounded,
  Icons.record_voice_over_rounded,
  Icons.waving_hand_rounded,
  Icons.help_rounded,
  // Actions & activity
  Icons.interests_rounded,
  Icons.sports_esports_rounded,
  Icons.music_note_rounded,
  Icons.menu_book_rounded,
  Icons.tv_rounded,
  Icons.directions_walk_rounded,
  // Places & things
  Icons.home_rounded,
  Icons.school_rounded,
  Icons.directions_car_rounded,
  Icons.park_rounded,
  Icons.light_mode_rounded,
  Icons.phone_rounded,
];

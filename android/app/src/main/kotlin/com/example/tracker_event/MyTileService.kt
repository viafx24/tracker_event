package com.example.tracker_event

import android.service.quicksettings.TileService
import android.service.quicksettings.Tile
import android.widget.Toast
import android.database.sqlite.SQLiteDatabase
import java.io.File

class MyTileService : TileService() {

    override fun onClick() {
        super.onClick()

        // Récupérer le chemin correct de la base sqflite
        val dbPath = applicationContext.getDatabasePath("events.db")

        if (!dbPath.exists()) {
            Toast.makeText(applicationContext, "Base de données introuvable", Toast.LENGTH_SHORT).show()
            return
        }

        // Ouvrir la base
        val db = SQLiteDatabase.openDatabase(dbPath.path, null, SQLiteDatabase.OPEN_READWRITE)

        // Insérer un événement
        val ts = System.currentTimeMillis()
        db.execSQL("INSERT INTO events(timestamp) VALUES($ts)")
        db.close()

        // Feedback visuel
        Toast.makeText(applicationContext, "Événement ajouté via Quick Tile !", Toast.LENGTH_SHORT).show()

        // Effet visuel sur le tile
        qsTile?.state = Tile.STATE_ACTIVE
        qsTile?.updateTile()
        android.os.Handler(mainLooper).postDelayed({
            qsTile?.state = Tile.STATE_INACTIVE
            qsTile?.updateTile()
        }, 500)
    }
}

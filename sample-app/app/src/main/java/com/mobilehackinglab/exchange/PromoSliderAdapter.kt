package com.mobilehackinglab.exchange

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import androidx.cardview.widget.CardView
import androidx.recyclerview.widget.RecyclerView

class PromoSliderAdapter(
    private val imageList: List<Int>,
    private val onClick: (Int) -> Unit
) : RecyclerView.Adapter<PromoSliderAdapter.PromoViewHolder>() {

    inner class PromoViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        val imageView: ImageView = itemView.findViewById(R.id.promo_image)
        val cardView: CardView = itemView.findViewById(R.id.promo_card_item)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): PromoViewHolder {
        val view = LayoutInflater.from(parent.context).inflate(R.layout.item_promo_slide, parent, false)
        return PromoViewHolder(view)
    }

    override fun onBindViewHolder(holder: PromoViewHolder, position: Int) {
        holder.imageView.setImageResource(imageList[position])
        holder.cardView.setOnClickListener {
            onClick(position) // Handle click event
        }
    }

    override fun getItemCount(): Int {
        return imageList.size
    }
}

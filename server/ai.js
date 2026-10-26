'use strict';

function normalizar(texto) {
  return (texto || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '');
}

/**
 * Motor de Asistencia Culinaria Inteligente de ChefCraft.
 * Opera en el servidor propio para responder sobre las recetas del catálogo,
 * sugerir platos según ingredientes, brindar sustituciones saludables y tips de preparación.
 */
function procesarConsultaCulinaria(mensaje, recetas = []) {
  const t = normalizar(mensaje);

  // 1. Recomendación por ingredientes disponibles
  const ingredientesComunes = [
    { clave: 'camaron', nombre: 'camarones', receta: 'Ceviche Clásico de Camarón' },
    { clave: 'pollo', nombre: 'pollo', receta: 'Seco de Pollo Criollo o Wrap Integral de Pollo' },
    { clave: 'platano', nombre: 'plátano verde/maduro', receta: 'Bolón de Verde con Queso o Pancake de Avena con Plátano' },
    { clave: 'verde', nombre: 'verde', receta: 'Bolón de Verde con Queso y Chicharrón' },
    { clave: 'quinoa', nombre: 'quinoa', receta: 'Ensalada Mediterránea de Quinoa' },
    { clave: 'calabaza', nombre: 'calabaza', receta: 'Sopa Cremosa de Calabaza y Jengibre' },
    { clave: 'avena', nombre: 'avena', receta: 'Pancake de Avena o Hamburguesa Vegana' },
    { clave: 'salmon', nombre: 'salmón', receta: 'Salmón al Horno con Hierbas y Espárragos' },
    { clave: 'papa', nombre: 'papas', receta: 'Locro de Papa Ecuatoriano o Tortilla Española' },
    { clave: 'aguacate', nombre: 'aguacate', receta: 'Mousse Saludable de Cacao o Wrap de Pollo' },
    { clave: 'cacao', nombre: 'cacao/chocolate', receta: 'Mousse Saludable de Cacao y Aguacate' },
    { clave: 'pescado', nombre: 'pescado', receta: 'Tacos de Pescado Baja Style' },
    { clave: 'arroz', nombre: 'arroz', receta: 'Risotto de Champiñones y Trufa' },
    { clave: 'champiñon', nombre: 'champiñones/hongos', receta: 'Risotto de Champiñones o Hamburguesa Vegana' },
    { clave: 'manzana', nombre: 'manzana', receta: 'Tarta Rústica de Manzana y Canela' },
    { clave: 'garbanzo', nombre: 'garbanzos', receta: 'Curry de Garbanzos y Espinacas al Coco' },
    { clave: 'lenteja', nombre: 'lentejas', receta: 'Hamburguesa Vegana de Lentejas' },
    { clave: 'queso', nombre: 'queso', receta: 'Cheesecake Horneado, Bolón de Verde o Locro de Papa' },
    { clave: 'huevo', nombre: 'huevos', receta: 'Tortilla Española o Pancakes de Avena' }
  ];

  const encontrados = ingredientesComunes.filter((item) => t.includes(item.clave));
  if (encontrados.length > 0) {
    const nombres = encontrados.map((i) => i.nombre).join(', ');
    const sugerencias = encontrados.map((i) => `• ${i.receta}`).join('\n');
    return {
      respuesta: `Con ${nombres} te recomiendo preparar:\n\n${sugerencias}\n\n¿Deseas conocer los pasos o el tiempo de cocción de alguna de ellas?`,
      sugerencias: encontrados.map((i) => i.receta),
      categoriaDetectada: 'ingredientes'
    };
  }

  // 2. Recomendación por categoría o momento del día
  if (t.includes('desayun') || t.includes('manana') || t.includes('amanecer')) {
    const desayunos = recetas.filter((r) => r.categoria === 'Desayuno');
    const titulos = desayunos.map((r) => `• ${r.titulo} (${r.tiempoMinutos} min, ${r.calorias} kcal)`).join('\n');
    return {
      respuesta: `Para empezar el día con energía te sugiero estas opciones de desayuno:\n\n${titulos}\n\nSon opciones balanceadas y fáciles de preparar en menos de 25 minutos.`,
      categoriaDetectada: 'Desayuno'
    };
  }

  if (t.includes('almuerzo') || t.includes('mediodia') || t.includes('comida fuerte')) {
    const almuerzos = recetas.filter((r) => r.categoria === 'Almuerzo').slice(0, 3);
    const titulos = almuerzos.map((r) => `• ${r.titulo} (${r.tiempoMinutos} min)`).join('\n');
    return {
      respuesta: `Para el almuerzo te recomiendo estos platos principales nutritivos:\n\n${titulos}\n\nTodos cuentan con un excelente balance de proteínas y carbohidratos saludables.`,
      categoriaDetectada: 'Almuerzo'
    };
  }

  if (t.includes('cena') || t.includes('noche') || t.includes('ligero') || t.includes('liviano')) {
    const cenas = recetas.filter((r) => r.categoria === 'Cena' || r.categoria === 'Saludable').slice(0, 3);
    const titulos = cenas.map((r) => `• ${r.titulo} (${r.calorias} kcal, ${r.tiempoMinutos} min)`).join('\n');
    return {
      respuesta: `Para una cena ligera y de fácil digestión te propongo:\n\n${titulos}\n\nSon bajas en grasas saturadas e ideales para un buen descanso nocturno.`,
      categoriaDetectada: 'Cena'
    };
  }

  if (t.includes('postre') || t.includes('dulce') || t.includes('antojo')) {
    const postres = recetas.filter((r) => r.categoria === 'Postre');
    const titulos = postres.map((r) => `• ${r.titulo} (${r.dificultad}, ${r.calorias} kcal)`).join('\n');
    return {
      respuesta: `Para consentirte de forma saludable tenemos estos deliciosos postres:\n\n${titulos}\n\nEl Mousse de Cacao utiliza aguacate para lograr una textura cremosa sin necesidad de crema de leche.`,
      categoriaDetectada: 'Postre'
    };
  }

  if (t.includes('saludable') || t.includes('fit') || t.includes('dieta') || t.includes('caloria')) {
    const saludables = recetas.filter((r) => r.categoria === 'Saludable' || r.calorias < 320).slice(0, 3);
    const titulos = saludables.map((r) => `• ${r.titulo} - Solo ${r.calorias} kcal`).join('\n');
    return {
      respuesta: `Nuestras recetas más bajas en calorías y densas en nutrientes son:\n\n${titulos}\n\n¿Te gustaría ver la lista completa de ingredientes de alguna?`,
      categoriaDetectada: 'Saludable'
    };
  }

  // 3. Sustituciones inteligentes
  if (t.includes('sustitu') || t.includes('reemplaz') || t.includes('cambiar')) {
    if (t.includes('huevo')) {
      return {
        respuesta: 'Para sustituir el huevo en horneados puedes usar: 1 cucharada de chía molida hidratada en 3 de agua (huevo de chía), o 1/2 plátano maduro machacado.',
        categoriaDetectada: 'sustitucion'
      };
    }
    if (t.includes('azucar')) {
      return {
        respuesta: 'Para sustituir el azúcar refinada te recomiendo puré de dátiles, miel de abeja cruda, stevia pura o puré de manzana asada.',
        categoriaDetectada: 'sustitucion'
      };
    }
    if (t.includes('crema') || t.includes('leche')) {
      return {
        respuesta: 'Para reemplazar la crema de leche puedes usar leche de coco entera refrigerada, yogur griego espeso o una pasta de castañas de cajú (anacardos).',
        categoriaDetectada: 'sustitucion'
      };
    }
    return {
      respuesta: 'Puedo sugerirte sustitutos para huevos, azúcar, leche, crema o harinas. ¿Qué ingrediente específico necesitas reemplazar?',
      categoriaDetectada: 'sustitucion'
    };
  }

  // 4. Saludo o consulta general
  if (t.includes('hola') || t.includes('buenos dias') || t.includes('buenas') || t.includes('ayuda')) {
    return {
      respuesta: `¡Hola! Soy tu asistente de cocina ChefCraft 👨‍🍳. Puedo ayudarte a:\n\n• Recomendar platos según lo que tengas en la nevera (ej: «¿qué cocino con pollo y aguacate?»)\n• Sugerir recetas por momento del día (desayuno, almuerzo, cena o postre)\n• Proponer alternativas saludables y bajas en calorías\n• Sugerir sustituciones inteligentes de ingredientes\n\n¿Qué te gustaría cocinar hoy?`,
      categoriaDetectada: 'general'
    };
  }

  // 5. Respuesta por defecto enriquecida
  return {
    respuesta: `Entendido. Como tu Chef Inteligente te sugiero explorar nuestro catálogo con más de ${recetas.length} recetas seleccionadas. Puedes preguntarme por ingredientes específicos como «pollo», «camarones», «quinoa», o pedirme recomendaciones de desayunos, almuerzos ligeros o postres saludables.`,
    categoriaDetectada: 'general'
  };
}

module.exports = {
  procesarConsultaCulinaria
};
